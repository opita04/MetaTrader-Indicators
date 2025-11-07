#!/usr/bin/env node
// Simple script to bump #property version "MAJOR.MINOR" in .mq4 files.
// - If files are passed as args, it updates those files.
// - Otherwise it reads `git status --porcelain` and updates modified .mq4 files.
// Behavior: increments MINOR by 1 and keeps it as two digits (e.g. 2.09 -> 2.10).

const fs = require('fs');
const { execSync } = require('child_process');

function getTargetFiles() {
    const args = process.argv.slice(2);
    if (args.length > 0) return args.filter(f => f.endsWith('.mq4') && fs.existsSync(f));

    try {
        const out = execSync('git status --porcelain', { encoding: 'utf8' });
        const files = out.split(/\r?\n/)
            .map(line => line.trim())
            .filter(Boolean)
            .map(line => {
                // status format: XY <path> or just <path> depending on git
                const parts = line.split(/\s+/);
                return parts.slice(1).join(' ') || parts[0];
            });
        return files.filter(f => f.endsWith('.mq4') && fs.existsSync(f));
    } catch (err) {
        console.error('Could not run git to detect changed files. Provide file paths as arguments instead.');
        return [];
    }
}

function bumpVersionInFile(filePath) {
    const content = fs.readFileSync(filePath, 'utf8');
    const regex = /#property\s+version\s+"(\d+)\.(\d{1,2})"/;
    const match = content.match(regex);
    if (!match) {
        console.log(`Skipping ${filePath}: no #property version found`);
        return;
    }

    let major = parseInt(match[1], 10);
    let minor = parseInt(match[2], 10);

    minor += 1;
    if (minor >= 100) {
        major += Math.floor(minor / 100);
        minor = minor % 100;
    }

    const minorStr = minor < 10 ? '0' + minor : String(minor);
    const newLine = `#property version   "${major}.${minorStr}"`;

    const newContent = content.replace(regex, newLine);

    // write a backup and then overwrite
    try {
        fs.copyFileSync(filePath, filePath + '.bak');
        fs.writeFileSync(filePath, newContent, 'utf8');
        console.log(`Updated ${filePath} -> ${major}.${minorStr} (backup: ${filePath}.bak)`);
    } catch (err) {
        console.error(`Failed to update ${filePath}:`, err.message);
    }
}

const targets = getTargetFiles();
if (targets.length === 0) {
    console.log('No .mq4 targets found. Provide one or more .mq4 file paths as arguments to the script.');
    process.exit(0);
}

for (const f of targets) bumpVersionInFile(f);


