# TestCustomPermissions
Test Apex using Custom Permissions with API to assign and unassign Custom Permissions on a test User

Test Setup
--------------

Use `TestCustomPermissions.testSetup()` to:
-  Insert a User with:
   -  **Profile** as **Standard User**
   -  **Username** as `[Organization's ID]-[Datetime's Now's Time]-[Crypto's Random Integer]@example.com`
   -  **Email** as **Username**
   -  **LastName** as `X` + **Username** converted into an API Name
-  Insert a Permission Set whose `Name` equals User's **LastName**

Testing Custom Permissions
--------------

Constructing `TestCustomPermissions.User`:
-  Sets its `User` as the first **Schema.User** whose:
   -  **Username** starts with **Organization's ID**
   -  **Email** starts with **Organization's ID**
   -  **LastName** starts with `X` + **Organization's ID**
-  Asserts `User` is not assigned any Custom Permission
-  Sets `Permission Set ID` as the first **Permission Set** whose `Name` equals **User's LastName**

TestCustomPermissions.User's Methods
-------------

`CustomPermission[] getAssignedCustomPermissions()`
- Returns a query of all **Custom Permissions** assigned to `Permission Set ID`

`Id getCustomPermissionId(String developerName)`
-  Returns the `Id` of the ** Custom Permission** whose **DeveloperName** equals `developerName`
-  Caches a `Map<String, Id>` of Custom Permission's DeveloperName -> ID.

`TestCustomPermissions.User assignCustomPermission(String developerName)`
-  If not already assigned, assigns **Custom Permission** whose **DeveloperName** equals `developerName` to `User`'s **Permission Set** with `Permission Set ID`
-  Asserts there exists a **Custom Permission** whose **DeveloperName**
-  Returns `this` for chaining

`TestCustomPermissions.User unassignCustomPermission(String developerName)`
-  If assigned, unassigns **Custom Permission** whose **DeveloperName** equals `developerName` to `User`'s **Permission Set** with `Permission Set ID`
-  Returns `this` for chaining

`TestCustomPermissions.User set(String developerName, Boolean isAssigned)`
-  Shorthand for **assignCustomPermission** and **unassignCustomPermission**
-  If `isAssigned` equals `true`, returns `assignCustomPermission(developerName)`
-  Else, returns `unassignCustomPermission(developerName)`

Example
------------
```apex
    public with sharing class Controller {

        public Boolean getIsFirstCustomPermission() {
            return FeatureManagement.checkPermission('First_Custom_Permission');
        }

        public Boolean getIsSecondCustomPermission() {
            return FeatureManagement.checkPermission('Second_Custom_Permission');
        }

    }


    @IsTest
    public with sharing class ControllerWithCustomPermission_Test {

        @TestSetup
        public static void testSetup() {
            TestCustomPermissions.testSetup();
        }

        @IsTest
        public static void testControllerWithCustomPermission() {
            // Data
            final TestCustomPermissions.User user = new TestCustomPermissions.User();
            final Boolean[] options = new Boolean[] {
                true, 
                false
            };

            // -----------  Start Test  -----------
            Test.startTest();

            // ControllerWithCustomPermission
            {
                for(Boolean isFirstCustomPermission : options) {
                    for(Boolean isSecondCustomPermission : options) {
                        // Set Custom Permissions
                        {
                            user
                                .set('First_Custom_Permission', isFirstCustomPermission)
                                .set('Second_Custom_Permission', isSecondCustomPermission);
                        }
                        
                        // Test
                        {
                            final Controller controller = new Controller();
                            System.assertEquals(isFirstCustomPermission, controller.getIsFirstCustomPermission());
                            System.assertEquals(isSecondCustomPermission, controller.getIsSecondCustomPermission());
                        }
                    }
                }
            }

            Test.stopTest();
            // -----------  Stop Test  -----------
        }
    }
```
