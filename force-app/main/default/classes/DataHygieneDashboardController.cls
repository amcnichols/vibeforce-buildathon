public with sharing class DataHygieneDashboardController {
    public class DashboardStats {
        @AuraEnabled
        public Integer recordsScanned;

        @AuraEnabled
        public Integer dirtyRecords;

        @AuraEnabled
        public Integer cleanedToday;
    }

    @AuraEnabled(cacheable=true)
    public static List<Lead> getDirtyLeads() {
        return [
            SELECT
                Id,
                FirstName,
                LastName,
                Name,
                Email,
                Phone,
                City,
                State,
                CreatedDate,
                Hygiene_Status__c,
                Hygiene_Score__c,
                Hygiene_Notes__c
            FROM Lead
            WHERE Hygiene_Status__c = 'Dirty' OR Hygiene_Status__c = NULL
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
            LIMIT 25
        ];
    }

    @AuraEnabled(cacheable=true)
    public static DashboardStats getDashboardStats() {
        DashboardStats stats = new DashboardStats();

        stats.recordsScanned = [
            SELECT COUNT()
            FROM Lead
            WITH SECURITY_ENFORCED
        ];

        stats.dirtyRecords = [
            SELECT COUNT()
            FROM Lead
            WHERE Hygiene_Status__c = 'Dirty' OR Hygiene_Status__c = NULL
            WITH SECURITY_ENFORCED
        ];

        Date today = Date.today();
        stats.cleanedToday = [
            SELECT COUNT()
            FROM Lead
            WHERE Hygiene_Status__c = 'Cleaned' AND LastModifiedDate = TODAY
            WITH SECURITY_ENFORCED
        ];

        return stats;
    }

    @AuraEnabled
    public static String cleanLeadRecord(Id leadId) {
        if (leadId == null) {
            return 'Please select a Lead to clean.';
        }

        try {
            Map<String, Object> inputs = new Map<String, Object>{ 'LeadId' => leadId };
            Flow.Interview.Lead_Data_Hygiene_Flow interview = new Flow.Interview.Lead_Data_Hygiene_Flow(
                inputs
            );
            interview.start();

            Lead cleanedLead = [
                SELECT FirstName, LastName, Name, Hygiene_Status__c, Hygiene_Notes__c
                FROM Lead
                WHERE Id = :leadId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];

            String displayName = String.isBlank(cleanedLead.Name)
                ? 'the selected Lead'
                : cleanedLead.Name;
            return 'Cleaned name and phone for ' + displayName + '. Status: ' + cleanedLead.Hygiene_Status__c + '.';
        } catch (Exception ex) {
            return 'Unable to clean the selected Lead. ' + ex.getMessage();
        }
    }

    @AuraEnabled
    public static String cleanAllDirtyLeads() {
        try {
            List<Lead> dirtyLeads = [
                SELECT
                    Id,
                    FirstName,
                    LastName,
                    Email,
                    Phone,
                    City,
                    State,
                    Hygiene_Status__c,
                    Hygiene_Notes__c,
                    Hygiene_Score__c
                FROM Lead
                WHERE Hygiene_Status__c = 'Dirty' OR Hygiene_Status__c = NULL
                WITH SECURITY_ENFORCED
                ORDER BY CreatedDate DESC
                LIMIT 25
            ];

            if (dirtyLeads.isEmpty()) {
                return 'No dirty Leads found. Everything looks clean.';
            }

            List<LeadHygieneNormalizer.NormalizationResult> normalizedResults = LeadHygieneNormalizer.normalizeLeads(
                dirtyLeads
            );
            Map<Id, LeadHygieneNormalizer.NormalizationResult> resultsById = new Map<Id, LeadHygieneNormalizer.NormalizationResult>();

            for (LeadHygieneNormalizer.NormalizationResult normalizedResult : normalizedResults) {
                resultsById.put(normalizedResult.leadId, normalizedResult);
            }

            List<Lead> leadsToUpdate = new List<Lead>();
            Integer cleanedCount = 0;
            Integer reviewCount = 0;

            for (Lead dirtyLead : dirtyLeads) {
                LeadHygieneNormalizer.NormalizationResult normalizedResult = resultsById.get(
                    dirtyLead.Id
                );
                if (normalizedResult == null) {
                    continue;
                }

                dirtyLead.FirstName = normalizedResult.firstName;
                dirtyLead.LastName = normalizedResult.lastName;
                dirtyLead.Email = normalizedResult.email;
                dirtyLead.Phone = normalizedResult.phone;
                dirtyLead.City = normalizedResult.city;
                dirtyLead.State = normalizedResult.state;
                dirtyLead.Hygiene_Status__c = normalizedResult.hygieneStatus;
                dirtyLead.Hygiene_Notes__c = normalizedResult.hygieneNotes;
                dirtyLead.Hygiene_Score__c = normalizedResult.hygieneScore;
                leadsToUpdate.add(dirtyLead);

                if (normalizedResult.hygieneStatus == 'Cleaned') {
                    cleanedCount++;
                } else if (normalizedResult.hygieneStatus == 'Needs Review') {
                    reviewCount++;
                }
            }

            if (!leadsToUpdate.isEmpty()) {
                update leadsToUpdate;
            }

            return 'Cleaned ' + cleanedCount + ' Leads, ' + reviewCount + ' marked as Needs Review.';
        } catch (Exception ex) {
            return 'Unable to clean all dirty Leads. ' + ex.getMessage();
        }
    }
}
