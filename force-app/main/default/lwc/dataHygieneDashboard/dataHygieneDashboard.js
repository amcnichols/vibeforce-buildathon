import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getDirtyLeads from '@salesforce/apex/DataHygieneDashboardController.getDirtyLeads';
import getDashboardStats from '@salesforce/apex/DataHygieneDashboardController.getDashboardStats';
import cleanLeadRecord from '@salesforce/apex/DataHygieneDashboardController.cleanLeadRecord';
import cleanAllDirtyLeads from '@salesforce/apex/DataHygieneDashboardController.cleanAllDirtyLeads';

export default class DataHygieneDashboard extends LightningElement {
    @track leads = [];
    @track selectedLead;
    @track isLoading = true;
    @track isCleaning = false;
    @track resultMessage;
    @track stats = {
        recordsScanned: 0,
        dirtyRecords: 0,
        cleanedToday: 0
    };

    _wiredLeadsResult;
    _wiredStatsResult;

    @wire(getDirtyLeads)
    wiredLeads(result) {
        this._wiredLeadsResult = result;
        this.isLoading = true;

        if (result.data) {
            this.leads = result.data.map((lead) => this.decorateLead(lead));
            if (this.selectedLead) {
                this.selectedLead = this.leads.find((lead) => lead.Id === this.selectedLead.Id) || null;
            }
        } else if (result.error) {
            this.showToast('Error', this.reduceError(result.error), 'error');
        }

        this.isLoading = false;
    }

    @wire(getDashboardStats)
    wiredStats(result) {
        this._wiredStatsResult = result;

        if (result.data) {
            this.stats = {
                recordsScanned: result.data.recordsScanned || 0,
                dirtyRecords: result.data.dirtyRecords || 0,
                cleanedToday: result.data.cleanedToday || 0
            };
        }
    }

    get hasLeads() {
        return this.leads.length > 0;
    }

    get hasSelectedLead() {
        return !!this.selectedLead;
    }

    get leadsWithClasses() {
        return this.leads;
    }

    get recordsScannedDisplay() {
        return this.stats.recordsScanned;
    }

    get dirtyRecordsDisplay() {
        return this.stats.dirtyRecords;
    }

    get cleanedTodayDisplay() {
        return this.stats.cleanedToday;
    }

    get selectedStatusLabel() {
        return this.selectedLead?.Hygiene_Status__c || 'Dirty';
    }

    get selectedBadgeClass() {
        return `badge ${this.getStatusClass(this.selectedLead?.Hygiene_Status__c)}`;
    }

    get issuesDescription() {
        if (this.selectedLead?.Hygiene_Notes__c) {
            return this.selectedLead.Hygiene_Notes__c;
        }

        return this.buildIssuePreview(this.selectedLead);
    }

    decorateLead(lead) {
        const status = lead.Hygiene_Status__c || 'Dirty';
        const cityState = [lead.City, lead.State].filter(Boolean).join(', ');

        return {
            ...lead,
            statusLabel: status,
            badgeClass: `badge ${this.getStatusClass(status)}`,
            cardClass: `record-card${this.selectedLead?.Id === lead.Id ? ' active' : ''}`,
            locationLabel: cityState || 'No city/state',
            showScore: lead.Hygiene_Score__c !== null && lead.Hygiene_Score__c !== undefined
        };
    }

    getStatusClass(status) {
        const normalized = (status || 'Dirty').toLowerCase();

        if (normalized === 'cleaned') {
            return 'badge-cleaned';
        }
        if (normalized === 'needs review') {
            return 'badge-review';
        }

        return 'badge-dirty';
    }

    buildIssuePreview(lead) {
        if (!lead) {
            return '';
        }

        const issues = [];

        if (lead.FirstName && lead.FirstName !== lead.FirstName.trim()) {
            issues.push('Extra whitespace in first name');
        }
        if (lead.LastName && lead.LastName === lead.LastName.toUpperCase()) {
            issues.push('Last name casing looks inconsistent');
        }
        if (lead.Email && lead.Email !== lead.Email.trim()) {
            issues.push('Email has leading or trailing spaces');
        }
        if (!lead.Phone) {
            issues.push('Phone is missing or incomplete');
        }
        if (lead.City && lead.City === lead.City.toLowerCase()) {
            issues.push('City casing looks inconsistent');
        }

        return issues.length ? issues.join('; ') : 'Record appears dirty and needs normalization.';
    }

    handleLeadSelect(event) {
        const leadId = event.currentTarget.dataset.id;
        this.selectedLead = this.leads.find((lead) => lead.Id === leadId) || null;
        this.resultMessage = null;
        this.leads = this.leads.map((lead) => this.decorateLead(lead));
    }

    async handleCleanSelected() {
        if (!this.selectedLead || this.isCleaning) {
            return;
        }

        this.isCleaning = true;
        this.resultMessage = null;

        try {
            const message = await cleanLeadRecord({ leadId: this.selectedLead.Id });
            this.resultMessage = message;
            this.showToast('Success', message, 'success');
            await this.refreshData();
        } catch (error) {
            const errorMessage = this.reduceError(error);
            this.resultMessage = errorMessage;
            this.showToast('Error', errorMessage, 'error');
        } finally {
            this.isCleaning = false;
        }
    }

    async handleCleanAll() {
        if (this.isCleaning) {
            return;
        }

        this.isCleaning = true;
        this.resultMessage = null;

        try {
            const message = await cleanAllDirtyLeads();
            this.resultMessage = message;
            this.showToast('Success', message, 'success');
            this.selectedLead = null;
            await this.refreshData();
        } catch (error) {
            const errorMessage = this.reduceError(error);
            this.resultMessage = errorMessage;
            this.showToast('Error', errorMessage, 'error');
        } finally {
            this.isCleaning = false;
        }
    }

    async handleRefresh() {
        this.selectedLead = null;
        this.resultMessage = null;
        await this.refreshData();
    }

    async refreshData() {
        await Promise.all([
            refreshApex(this._wiredLeadsResult),
            refreshApex(this._wiredStatsResult)
        ]);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((item) => item.message).join(', ');
        }

        return error?.body?.message || error?.message || 'An unexpected error occurred.';
    }
}
