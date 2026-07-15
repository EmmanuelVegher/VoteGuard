const fs = require('fs');

const fileData = fs.readFileSync('/Users/mac/voteguard/scratch/parties.json', 'utf8');
const data = JSON.parse(fileData);

const documents = data.documents || [];
console.log(`Found ${documents.length} parties:`);

documents.forEach(doc => {
  const fields = doc.fields || {};
  const name = fields.name?.stringValue || '';
  const abbreviation = fields.abbreviation?.stringValue || '';
  const logoUrl = fields.logoUrl?.stringValue || '';
  const isActive = fields.isActive?.booleanValue;
  console.log(`- [${abbreviation}] ${name}: ${logoUrl} (Active: ${isActive})`);
});
