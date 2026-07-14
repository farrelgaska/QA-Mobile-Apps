const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const findTestFiles = directory => fs.readdirSync(directory, { withFileTypes: true })
  .flatMap(entry => {
    const fullPath = path.join(directory, entry.name);
    if (entry.isDirectory()) return findTestFiles(fullPath);
    return entry.isFile() && entry.name.endsWith('.test.js') ? [fullPath] : [];
  })
  .sort();

const runRepositoryTests = () => {
  const testsDirectory = path.join(__dirname, '../test/repositories');
  const testFiles = findTestFiles(testsDirectory);
  if (testFiles.length === 0) throw new Error('No repository tests found');
  execFileSync(process.execPath, ['--test', ...testFiles], { stdio: 'inherit' });
};

if (require.main === module) runRepositoryTests();

module.exports = { findTestFiles, runRepositoryTests };
