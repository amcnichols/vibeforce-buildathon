import { chromium } from '@playwright/test';
import { execSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

const SCREENSHOT_DIR = path.resolve('screenshots');
const TARGET_ORG = 'vf-scratch';

function runStep(stepName, checkFn) {
    console.log(`STEP: ${stepName}`);
    return checkFn();
}

function sfJson(args) {
    return JSON.parse(execSync(`sf ${args} --target-org ${TARGET_ORG} --json`, { encoding: 'utf8' }));
}

function sfDataQuery(soql) {
    const encoded = encodeURIComponent(soql);
    const result = sfJson(`data query --query "${soql.replace(/"/g, '\\"')}"`);
    return result.result.records;
}

function screenshot(page, name) {
    fs.mkdirSync(SCREENSHOT_DIR, { recursive: true });
    const filePath = path.join(SCREENSHOT_DIR, `${name}.png`);
    return page.screenshot({ path: filePath, fullPage: true });
}

async function getUrls() {
    const org = sfJson('org display').result;
    const lexBase = org.instanceUrl.replace('.my.salesforce.com', '.lightning.force.com');
    const frontdoor = JSON.parse(
        execSync(`sf org open --target-org ${TARGET_ORG} --url-only --json`, { encoding: 'utf8' })
    ).result.url;
    return { lexBase, frontdoor };
}

async function main() {
    let failedStep = null;
    const browser = await chromium.launch({ headless: false, slowMo: 300 });
    const page = await browser.newPage();

    try {
        const { lexBase, frontdoor } = await getUrls();
        const dirtyBefore = sfDataQuery(
            "SELECT COUNT() cnt FROM Lead WHERE Hygiene_Status__c = 'Dirty' OR Hygiene_Status__c = NULL"
        );

        await runStep('Login via frontdoor URL', async () => {
            await page.goto(frontdoor);
            await page.waitForLoadState('domcontentloaded');
            await page.waitForTimeout(3000);
            await screenshot(page, '01-login');
        });

        await runStep('Open Data Hygiene Dashboard tab', async () => {
            await page.goto(`${lexBase}/lightning/n/Data_Hygiene_Dashboard`);
            await page.waitForLoadState('domcontentloaded');
            await page.waitForTimeout(3000);
            await screenshot(page, '02-dashboard');
        });

        await runStep('Verify dashboard title is visible', async () => {
            const title = page.getByText('Data Hygiene Dashboard', { exact: false });
            if (!(await title.first().isVisible())) {
                throw new Error('Dashboard title not visible');
            }
        });

        await runStep('Verify three stat cards render', async () => {
            for (const label of ['Records Scanned', 'Dirty Records', 'Cleaned Today']) {
                if (!(await page.getByText(label, { exact: false }).first().isVisible())) {
                    throw new Error(`Stat card missing: ${label}`);
                }
            }
            await screenshot(page, '03-stat-cards');
        });

        await runStep('Verify at least one dirty Lead is listed', async () => {
            const cards = page.locator('.record-card');
            const count = await cards.count();
            if (count < 1) {
                throw new Error('No dirty Lead cards found');
            }
            await screenshot(page, '04-dirty-list');
        });

        await runStep('Select the first dirty Lead', async () => {
            await page.locator('.record-card').first().click();
            await page.waitForTimeout(1000);
            await screenshot(page, '05-selected-lead');
        });

        await runStep('Verify detail panel and Clean Selected Record button', async () => {
            const cleanButton = page.getByRole('button', { name: 'Clean Selected Record' });
            if (!(await cleanButton.isVisible())) {
                throw new Error('Clean Selected Record button not visible');
            }
        });

        await runStep('Click Clean Selected Record', async () => {
            await page.getByRole('button', { name: 'Clean Selected Record' }).click();
            await page.waitForTimeout(4000);
            await screenshot(page, '06-after-clean');
        });

        await runStep('Verify success message or toast and dirty count decreased', async () => {
            const toastOrResult = page.locator('.result-panel, .slds-notify_toast');
            if (!(await toastOrResult.first().isVisible())) {
                throw new Error('No success toast or result panel found');
            }

            const dirtyAfterRecords = sfDataQuery(
                "SELECT Id FROM Lead WHERE Hygiene_Status__c = 'Dirty' OR Hygiene_Status__c = NULL LIMIT 200"
            );
            if (dirtyAfterRecords.length >= dirtyBefore.length) {
                throw new Error('Dirty Lead count did not decrease after cleanup');
            }

            await screenshot(page, '07-success');
        });

        console.log('All Playwright validation steps passed.');
        await browser.close();
        process.exit(0);
    } catch (error) {
        failedStep = error.message;
        await screenshot(page, 'failure');
        await browser.close();
        console.error(`FAILED STEP: ${failedStep}`);
        process.exit(1);
    }
}

main();
