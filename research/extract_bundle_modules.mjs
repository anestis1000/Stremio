// Parse the extracted bundle as inert text. Never import or execute target code.
import fs from 'node:fs';
import crypto from 'node:crypto';
import { parse } from '/Users/a.tsoulfas/.npm/_npx/ad9a3fdbcad992c6/node_modules/@babel/parser/lib/index.js';

const input = '/tmp/stremio-extracted-v5.0.27-arm64/app/server.js';
const source = fs.readFileSync(input, 'utf8');
const ast = parse(source, { sourceType: 'script' });
const call = ast.program.body[0].expression.argument;
if (call.type !== 'CallExpression' || call.arguments[0].type !== 'ArrayExpression') {
  throw new Error('Unexpected Webpack bootstrap shape');
}
const output = '/tmp/stremio-server-derived-modules';
fs.mkdirSync(output, { recursive: true });
const manifest = [];
for (const [index, node] of call.arguments[0].elements.entries()) {
  if (!node) continue;
  const text = source.slice(node.start, node.end);
  const reasons = [];
  if (index === 576) reasons.push('bootstrap entry ordinal');
  if (text.includes('name: "stremio-server"')) reasons.push('embedded server package metadata');
  if (text.includes('server.listen(port)') && text.includes('11470')) reasons.push('HTTP listener configuration');
  if (text.includes('subtitles.vtt') && text.includes('router.')) reasons.push('subtitle route candidate');
  if (!reasons.length) continue;
  const path = `module-${index}.js`;
  // Parentheses only make the exact factory range a valid standalone expression.
  fs.writeFileSync(`${output}/${path}`, `(${text});\n`);
  manifest.push({ path, ordinal: index, reasons, original_start_utf16: node.start,
    original_end_utf16: node.end, original_start_byte: Buffer.byteLength(source.slice(0, node.start)),
    original_end_byte: Buffer.byteLength(source.slice(0, node.end)),
    original_sha256: crypto.createHash('sha256').update(text).digest('hex'),
    derived_sha256: crypto.createHash('sha256').update(`(${text});\n`).digest('hex') });
}
const result = { input, input_sha256: crypto.createHash('sha256').update(source).digest('hex'),
  total_factory_slots: call.arguments[0].elements.length, output,
  limitation: 'Factory ordinals are build-local; selected slices do not resolve dependencies or establish runtime reachability.', modules: manifest };
fs.writeFileSync('research/evidence/derived-module-provenance.json', JSON.stringify(result, null, 2) + '\n');
console.log(JSON.stringify(result, null, 2));
