public with sharing class LeadHygieneNormalizer {
    public class NormalizationResult {
        @InvocableVariable(label='Lead Id' required=true)
        public Id leadId;

        @InvocableVariable(label='First Name')
        public String firstName;

        @InvocableVariable(label='Last Name')
        public String lastName;

        @InvocableVariable(label='Email')
        public String email;

        @InvocableVariable(label='Phone')
        public String phone;

        @InvocableVariable(label='City')
        public String city;

        @InvocableVariable(label='State')
        public String state;

        @InvocableVariable(label='Hygiene Status')
        public String hygieneStatus;

        @InvocableVariable(label='Hygiene Notes')
        public String hygieneNotes;

        @InvocableVariable(label='Hygiene Score')
        public Decimal hygieneScore;
    }

    @InvocableMethod(label='Normalize Lead Hygiene')
    public static List<NormalizationResult> normalizeLeads(List<Lead> inputs) {
        List<NormalizationResult> results = new List<NormalizationResult>();

        for (Lead input : inputs) {
            results.add(normalizeLead(input));
        }

        return results;
    }

    public static NormalizationResult normalizeLead(Lead input) {
        NormalizationResult result = new NormalizationResult();
        result.leadId = input.Id;

        String rawFirst = input.FirstName;
        String rawLast = input.LastName;
        String rawEmail = input.Email;
        String rawPhone = input.Phone;
        String rawCity = input.City;
        String rawState = input.State;

        result.firstName = toProperCase(trimValue(rawFirst));
        result.lastName = toProperCase(trimValue(rawLast));
        result.email = trimValue(rawEmail)?.toLowerCase();
        result.city = toProperCase(trimValue(rawCity));
        result.state = trimValue(rawState)?.toUpperCase();

        List<String> changes = new List<String>();
        List<String> reviewItems = new List<String>();
        Integer issueCount = 0;

        issueCount += trackChange(changes, 'First Name', rawFirst, result.firstName);
        issueCount += trackChange(changes, 'Last Name', rawLast, result.lastName);
        issueCount += trackChange(changes, 'Email', rawEmail, result.email);
        issueCount += trackChange(changes, 'City', rawCity, result.city);
        issueCount += trackChange(changes, 'State', rawState, result.state);

        PhoneNormalization phoneResult = normalizePhone(rawPhone);
        result.phone = phoneResult.normalizedPhone;
        if (phoneResult.changed) {
            changes.add('Phone formatted to ' + result.phone);
        }
        if (phoneResult.needsReview) {
            reviewItems.add(phoneResult.reviewReason);
            issueCount++;
        } else {
            issueCount += trackChange(changes, 'Phone', rawPhone, result.phone);
        }

        if (reviewItems.isEmpty()) {
            result.hygieneStatus = 'Cleaned';
            result.hygieneScore = issueCount > 0 ? 80 : 100;
        } else {
            result.hygieneStatus = 'Needs Review';
            result.hygieneScore = 80;
        }

        if (changes.isEmpty() && reviewItems.isEmpty()) {
            result.hygieneNotes = 'No changes required; record already looked clean.';
        } else {
            List<String> notes = new List<String>();
            if (!changes.isEmpty()) {
                notes.add('Updated: ' + String.join(changes, '; ') + '.');
            }
            if (!reviewItems.isEmpty()) {
                notes.add('Needs review: ' + String.join(reviewItems, '; ') + '.');
            }
            result.hygieneNotes = String.join(notes, ' ');
        }

        if (issueCount > 0 && result.hygieneScore == 100) {
            result.hygieneScore = 80;
        } else if (issueCount > 2 && result.hygieneStatus == 'Needs Review') {
            result.hygieneScore = 40;
        }

        return result;
    }

    private static String trimValue(String value) {
        return value == null ? null : value.trim();
    }

    private static Integer trackChange(
        List<String> changes,
        String fieldLabel,
        String original,
        String normalized
    ) {
        String originalComparable = original == null ? null : original.trim();
        String normalizedComparable = normalized == null ? null : normalized.trim();

        if (originalComparable == normalizedComparable) {
            return looksMessy(originalComparable) ? 1 : 0;
        }

        if (String.isBlank(originalComparable) && String.isBlank(normalizedComparable)) {
            return 0;
        }

        changes.add(fieldLabel);
        return 1;
    }

    private static Boolean looksMessy(String value) {
        if (String.isBlank(value)) {
            return false;
        }

        return value != value.trim()
            || value.toLowerCase() == value && value.contains(' ')
            || value.toUpperCase() == value;
    }

    private static String toProperCase(String value) {
        if (String.isBlank(value)) {
            return value;
        }

        List<String> words = value.toLowerCase().split('\\s+');
        List<String> properWords = new List<String>();

        for (String word : words) {
            if (String.isBlank(word)) {
                continue;
            }
            properWords.add(word.substring(0, 1).toUpperCase() + word.substring(1));
        }

        return String.join(properWords, ' ');
    }

    private class PhoneNormalization {
        public String normalizedPhone;
        public Boolean changed = false;
        public Boolean needsReview = false;
        public String reviewReason;
    }

    private static PhoneNormalization normalizePhone(String rawPhone) {
        PhoneNormalization phoneResult = new PhoneNormalization();
        phoneResult.normalizedPhone = rawPhone == null ? null : rawPhone.trim();

        if (String.isBlank(phoneResult.normalizedPhone)) {
            phoneResult.needsReview = true;
            phoneResult.reviewReason = 'Phone is missing';
            return phoneResult;
        }

        String digits = phoneResult.normalizedPhone.replaceAll('[^0-9]', '');

        if (digits.length() == 11 && digits.startsWith('1')) {
            digits = digits.substring(1);
        }

        if (digits.length() == 10) {
            String formatted =
                '+1 (' +
                digits.substring(0, 3) +
                ') ' +
                digits.substring(3, 6) +
                '-' +
                digits.substring(6);
            phoneResult.changed = formatted != phoneResult.normalizedPhone;
            phoneResult.normalizedPhone = formatted;
            return phoneResult;
        }

        phoneResult.needsReview = true;
        phoneResult.reviewReason = 'Phone could not be normalized to +1 (###) ###-####';
        return phoneResult;
    }
}
