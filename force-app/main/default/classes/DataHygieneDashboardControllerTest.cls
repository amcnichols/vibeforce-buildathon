@IsTest
private class DataHygieneDashboardControllerTest {
    @TestSetup
    static void setupData() {
        List<Lead> leads = new List<Lead>{
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
        insert leads;
    }

    @IsTest
    static void testGetDirtyLeadsReturnsDirtyRecords() {
        Test.startTest();
        List<Lead> dirtyLeads = DataHygieneDashboardController.getDirtyLeads();
        Test.stopTest();

        System.assertEquals(2, dirtyLeads.size(), 'Only dirty or null-status Leads should return');
    }

    @IsTest
    static void testGetDashboardStats() {
        Test.startTest();
        DataHygieneDashboardController.DashboardStats stats = DataHygieneDashboardController.getDashboardStats();
        Test.stopTest();

        System.assertEquals(3, stats.recordsScanned);
        System.assertEquals(2, stats.dirtyRecords);
    }

    @IsTest
    static void testCleanLeadRecordViaFlow() {
        Lead dirtyLead = [
            SELECT Id, Name
            FROM Lead
            WHERE LastName = 'SMITH'
            LIMIT 1
        ];

        Test.startTest();
        String message = DataHygieneDashboardController.cleanLeadRecord(dirtyLead.Id);
        Test.stopTest();

        System.assert(message.contains('Cleaned'), message);

        Lead updatedLead = [
            SELECT Hygiene_Status__c, FirstName, LastName, Phone
            FROM Lead
            WHERE Id = :dirtyLead.Id
        ];
        System.assertNotEquals('Dirty', updatedLead.Hygiene_Status__c);
        System.assertEquals('John', updatedLead.FirstName);
    }

    @IsTest
    static void testCleanLeadRecordHandlesNullId() {
        Test.startTest();
        String message = DataHygieneDashboardController.cleanLeadRecord(null);
        Test.stopTest();

        System.assertEquals('Please select a Lead to clean.', message);
    }

    @IsTest
    static void testCleanAllDirtyLeads() {
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

    @IsTest
    static void testCleanAllDirtyLeadsWhenAlreadyClean() {
        delete [SELECT Id FROM Lead WHERE Hygiene_Status__c = 'Dirty' OR Hygiene_Status__c = NULL];

        Test.startTest();
        String message = DataHygieneDashboardController.cleanAllDirtyLeads();
        Test.stopTest();

        System.assertEquals('No dirty Leads found. Everything looks clean.', message);
    }

    @IsTest
    static void testLeadHygieneNormalizerMarksReviewWhenPhoneInvalid() {
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
