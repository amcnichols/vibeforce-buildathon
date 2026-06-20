@IsTest
private class DataHygieneDashboardControllerTest {
    private static User hygieneUser;

    @TestSetup
    static void setupData() {
        Profile standardProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        hygieneUser = new User(
            Alias = 'hygien',
            Email = 'hygiene.test@example.com',
            EmailEncodingKey = 'UTF-8',
            FirstName = 'Hygiene',
            LastName = 'Tester',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = standardProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'hygiene.tester.' + String.valueOf(DateTime.now().getTime()) + '@example.com'
        );
        insert hygieneUser;

        PermissionSet accessSet = [
            SELECT Id
            FROM PermissionSet
            WHERE Name = 'Data_Hygiene_Dashboard_Access'
            LIMIT 1
        ];
        insert new PermissionSetAssignment(
            AssigneeId = hygieneUser.Id,
            PermissionSetId = accessSet.Id
        );

        System.runAs(hygieneUser) {
            insert new List<Lead>{
                new Lead(
                    FirstName = ' jOhN ',
                    LastName = 'SMITH',
                    Company = 'Acme',
                    City = 'new york',
                    Phone = '5551234567',
                    Hygiene_Status__c = 'Dirty'
                ),
                new Lead(
                    FirstName = 'mARIA',
                    LastName = 'lopez',
                    Company = 'Globex',
                    Email = ' maria@example.com ',
                    Phone = '(404)-555-8899',
                    Hygiene_Status__c = 'Dirty'
                ),
                new Lead(
                    FirstName = 'Clean',
                    LastName = 'Record',
                    Company = 'Already Good',
                    Email = 'clean@example.com',
                    Phone = '+1 (555) 555-0100',
                    City = 'Boston',
                    State = 'MA',
                    Hygiene_Status__c = 'Cleaned',
                    Hygiene_Score__c = 100
                )
            };
        }
    }

    private static User getHygieneUser() {
        return [
            SELECT Id
            FROM User
            WHERE Alias = 'hygien'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
    }

    @IsTest
    static void testGetDirtyLeadsReturnsDirtyRecords() {
        System.runAs(getHygieneUser()) {
            Test.startTest();
            List<Lead> dirtyLeads = DataHygieneDashboardController.getDirtyLeads();
            Test.stopTest();

            System.assertEquals(2, dirtyLeads.size(), 'Only dirty or null-status Leads should return');
        }
    }

    @IsTest
    static void testGetDashboardStats() {
        System.runAs(getHygieneUser()) {
            Test.startTest();
            DataHygieneDashboardController.DashboardStats stats = DataHygieneDashboardController.getDashboardStats();
            Test.stopTest();

            System.assertEquals(3, stats.recordsScanned);
            System.assertEquals(2, stats.dirtyRecords);
        }
    }

    @IsTest
    static void testCleanLeadRecordViaFlow() {
        User user = getHygieneUser();
        Id leadId;

        System.runAs(user) {
            leadId = [SELECT Id FROM Lead WHERE LastName = 'SMITH' LIMIT 1].Id;
        }

        System.runAs(user) {
            Test.startTest();
            String message = DataHygieneDashboardController.cleanLeadRecord(leadId);
            Test.stopTest();

            System.assert(message.contains('Cleaned'), message);

            Lead updatedLead = [
                SELECT Hygiene_Status__c, FirstName, LastName, Phone
                FROM Lead
                WHERE Id = :leadId
            ];
            System.assertNotEquals('Dirty', updatedLead.Hygiene_Status__c);
            System.assertEquals('John', updatedLead.FirstName);
        }
    }

    @IsTest
    static void testCleanLeadRecordHandlesNullId() {
        System.runAs(getHygieneUser()) {
            Test.startTest();
            String message = DataHygieneDashboardController.cleanLeadRecord(null);
            Test.stopTest();

            System.assertEquals('Please select a Lead to clean.', message);
        }
    }

    @IsTest
    static void testCleanAllDirtyLeads() {
        System.runAs(getHygieneUser()) {
            Test.startTest();
            String message = DataHygieneDashboardController.cleanAllDirtyLeads();
            Test.stopTest();

            System.assert(message.contains('Cleaned'), message);

            Integer remainingDirty = [
                SELECT COUNT()
                FROM Lead
                WHERE Hygiene_Status__c = 'Dirty' OR Hygiene_Status__c = NULL
            ];
            System.assertEquals(0, remainingDirty);
        }
    }

    @IsTest
    static void testCleanAllDirtyLeadsWhenAlreadyClean() {
        User user = getHygieneUser();

        System.runAs(user) {
            delete [SELECT Id FROM Lead WHERE Hygiene_Status__c = 'Dirty' OR Hygiene_Status__c = NULL];
        }

        System.runAs(user) {
            Test.startTest();
            String message = DataHygieneDashboardController.cleanAllDirtyLeads();
            Test.stopTest();

            System.assertEquals('No dirty Leads found. Everything looks clean.', message);
        }
    }

    @IsTest
    static void testLeadHygieneNormalizerMarksReviewWhenPhoneInvalid() {
        User user = getHygieneUser();

        System.runAs(user) {
            Lead reviewLead = new Lead(
                FirstName = 'Bad',
                LastName = 'Phone',
                Company = 'Review Co',
                Phone = '123',
                Hygiene_Status__c = 'Dirty'
            );
            insert reviewLead;

            Test.startTest();
            LeadHygieneNormalizer.NormalizationResult result = LeadHygieneNormalizer.normalizeLead(reviewLead);
            Test.stopTest();

            System.assertEquals('Needs Review', result.hygieneStatus);
            System.assert(result.hygieneNotes.contains('Needs review'));
        }
    }
}
