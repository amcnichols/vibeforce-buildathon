List<Lead> messyLeads = new List<Lead>{
    new Lead(
        FirstName = ' jOhN ',
        LastName = 'SMITH',
        Company = 'Acme Steel',
        City = 'new york',
        State = 'ny',
        Phone = '5551234567',
        Email = 'john.smith@example.com',
        Hygiene_Status__c = 'Dirty',
        Hygiene_Score__c = 40
    ),
    new Lead(
        FirstName = 'mARIA',
        LastName = 'lopez',
        Company = 'Globex',
        Email = ' maria@example.com ',
        Phone = '(404)-555-8899',
        Hygiene_Status__c = 'Dirty',
        Hygiene_Score__c = 40
    ),
    new Lead(
        FirstName = '  alex  ',
        LastName = 'JOHNSON',
        Company = 'Northwind',
        City = 'san francisco',
        Phone = '415.555.0199',
        Hygiene_Status__c = 'Dirty',
        Hygiene_Score__c = 40
    ),
    new Lead(
        FirstName = 'Priya',
        LastName = 'patel',
        Company = 'Initech',
        Email = 'priya@example.com',
        Phone = '1-212-555-0188',
        Hygiene_Status__c = 'Dirty',
        Hygiene_Score__c = 40
    ),
    new Lead(
        FirstName = 'TOM',
        LastName = 'wilson',
        Company = 'Umbrella',
        City = 'CHICAGO',
        Phone = '3125550177',
        Hygiene_Status__c = null,
        Hygiene_Score__c = null
    ),
    new Lead(
        FirstName = '  sara ',
        LastName = ' O\'NEIL ',
        Company = 'Wayne Corp',
        Email = 'SARA@EXAMPLE.COM',
        Phone = '555-000-1234',
        Hygiene_Status__c = null,
        Hygiene_Score__c = null
    ),
    new Lead(
        FirstName = 'bad',
        LastName = 'phone',
        Company = 'Review LLC',
        Email = 'badphone@example.com',
        Phone = '123',
        Hygiene_Status__c = 'Dirty',
        Hygiene_Score__c = 40
    )
};

insert messyLeads;

System.debug('Inserted ' + messyLeads.size() + ' messy Leads for the Data Hygiene Dashboard.');
