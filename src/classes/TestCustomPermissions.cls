/**
 * @description 
 */
@IsTest
public with sharing class TestCustomPermissions {
	static final Schema.User RUNNING_USER;
	static {
		RUNNING_USER = [
			SELECT Id
			FROM User
			WHERE Id = :UserInfo.getUserId()
			LIMIT 1
		];
	}
	public static Schema.User getRunningUser() {
		return RUNNING_USER;
	}

	public static void testSetup() {
		final String username = String.join(
			new String[] {
				UserInfo.getOrganizationId(), 
				String.valueOf(DateTime.now().getTime()), 
				String.valueOf(Crypto.getRandomInteger())
			}, 
			'-'
		).left(68) + '@example.com';
		Schema.User user = new Schema.User(
			Username = username,
			Email = username,
			LastName = 'X' + (username.left(79)).replaceAll('\\W+', '_').replace('_{2,}', '_'), 
			Alias = String.valueOf(Crypto.getRandomInteger()).left(8),
			EmailEncodingKey = 'UTF-8',
			LanguageLocaleKey = 'en_US',
			LocaleSidKey = 'en_US',
			TimeZoneSidKey = 'America/New_York', 
			IsActive = true, 
			ProfileId = [
				SELECT Id
				FROM Profile
				WHERE Name = 'Standard User'
				LIMIT 1
			][0].Id
		);
		PermissionSet permissionSet = new PermissionSet(
			Name = user.LastName, 
			Label = user.Username
		);

		// Insert new Standard User
		System.runAs(getRunningUser()) {
			insert user;
		}

		// Insert Permission Set
		System.runAs(getRunningUser()) {
			insert permissionSet;	

			insert new PermissionSetAssignment(
				PermissionSetId = permissionSet.Id, 
				AssigneeId = user.Id
			);
		}
	}

	public with sharing class User {
		final Schema.User u;
		final Id p;
		final Map<String, Id> s;
		Map<String, Id> c;

		public User() {
			// Set User
			{
				Schema.User[] users = [
					SELECT Id, Username, LastName
					FROM User
					WHERE Username LIKE :(UserInfo.getOrganizationId() + '%')
					AND Email LIKE :(UserInfo.getOrganizationId() + '%')
					AND LastName LIKE :('X' + UserInfo.getOrganizationId() + '%')
					ORDER BY CreatedDate DESC
					LIMIT 1
				];
				this.u = users.isEmpty() ? null : users[0];
				System.assertNotEquals(null, this.u);
			}

			// Assert has no assigned Custom Permissions
			{
				Set<Id> assignedPermissionSetIds = new Set<Id>();
				for(PermissionSetAssignment permissionSetAssignment : [
					SELECT PermissionSetId 
					FROM PermissionSetAssignment
					WHERE AssigneeId = :this.getUser().Id
				]) {
					assignedPermissionSetIds.add(permissionSetAssignment.PermissionSetId);
				}

				System.assertEquals(
					true, 
					[
						SELECT Id, DeveloperName
						FROM CustomPermission
						WHERE Id IN (
							SELECT SetupEntityId 
							FROM SetupEntityAccess
							WHERE SetupEntityType = 'CustomPermission' 
							AND ParentId IN :assignedPermissionSetIds
						)
					].isEmpty()
				);
			}

			// Set Permission Set Id
			{
				PermissionSetAssignment[] permissionSetAssignments = [
					SELECT PermissionSetId,  PermissionSet.Name
					FROM PermissionSetAssignment
					WHERE AssigneeId = :this.getUser().Id
					AND PermissionSet.ProfileId = null
				];
				final Integer permissionSetAssignmentsSize = permissionSetAssignments.size();
				new Debugger('CustomPermissionUser')
					.add('User', this.getUser())
					.add('permissionSetAssignments', permissionSetAssignments)
					.assertEquals(1, permissionSetAssignments.size())
					.assertEquals(this.getUser().LastName, permissionSetAssignments[0].PermissionSet.Name);
				this.p = permissionSetAssignments[0].PermissionSetId;
			}

			// Assert User has no assigned Custom Permissions
			System.assertEquals(true, this.getAssignedCustomPermissions().isEmpty());

			// Set Setup Entity Access IDs
			this.s = new Map<String, Id>();
		}

		public Schema.User getUser() {
			return this.u;
		}

		public Id getPermissionSetId() {
			return this.p;
		}

		public CustomPermission[] getAssignedCustomPermissions() {
			return [
				SELECT Id, DeveloperName
				FROM CustomPermission
				WHERE Id IN (
					SELECT SetupEntityId 
					FROM SetupEntityAccess
					WHERE SetupEntityType = 'CustomPermission' 
					AND ParentId = :this.getPermissionSetId()
				)
			];
		}

		public Id getCustomPermissionId(String developerName) {
			if(this.c == null) {
				this.c = new Map<String, Id>();
				for(CustomPermission customPermission : [
					SELECT Id, DeveloperName
					FROM CustomPermission
					ORDER BY DeveloperName
				]) {
					this.c.put(customPermission.DeveloperName, customPermission.Id);
				}
			}
			return this.c.get(developerName);
		}

		private Map<String, Id> getSetupAccessEntityIds() {
			return this.s;
		}

		public User assignCustomPermission(String developerName) {
			if(this.getSetupAccessEntityIds().get(developerName) == null) {
				Id customPermissionId = this.getCustomPermissionId(developerName);
				System.assertNotEquals(null, customPermissionId, 'No CustomPermission found with DeveloperName: ' + developerName);
				SetupEntityAccess setupEntityAccess = new SetupEntityAccess(
					ParentId = this.getPermissionSetId(), 
					SetupEntityId = customPermissionId
				);
				System.runAs(getRunningUser()) {
					insert setupEntityAccess;
					this.s.put(developerName, setupEntityAccess.Id);
					System.assertEquals(true, FeatureManagement.checkPermission(developerName));
				}
			}
			return this;
		}

		public User unassignCustomPermission(String developerName) {
			Object setupEntityAccessId = this.getSetupAccessEntityIds().remove(developerName);
			if(setupEntityAccessId != null) {
				Database.delete((Id) setupEntityAccessId);
			}
			return this;
		}

		public User set(String developerName, Boolean isAssigned) {
			if(isAssigned == true) {
				return this.assignCustomPermission(developerName);
			}
			return this.unassignCustomPermission(developerName);
		}
	}
}