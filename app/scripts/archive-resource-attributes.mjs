import { lstatSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";

// A source archive has no Git attribute resolver. Accept the repository's
// deliberately small attribute grammar, rejecting ambiguous patterns instead
// of approximating Git's pattern, macro, quoting or override semantics.
const disjointWildcardRules = new Set([
  "*.rs text eol=lf",
  "qa/specimens/*.dvc -text",
  "vendor/ndi-sdk-6.3.2-headers/** -text -whitespace",
]);

function optionalRegularFile(path) {
  try {
    const stat = lstatSync(path);
    if (!stat.isFile() || stat.isSymbolicLink()) {
      throw new Error(`Archive attribute policy must be a regular file: ${path}`);
    }
    return true;
  } catch (error) {
    if (error?.code === "ENOENT") return false;
    throw error;
  }
}

export function verifyArchiveResourceAttributes(workspace, requiredLines) {
  const rootPolicy = join(workspace, ".gitattributes");
  if (!optionalRegularFile(rootPolicy)) {
    throw new Error("Source archive is missing the root .gitattributes policy.");
  }
  const lines = readFileSync(rootPolicy, "utf8").split(/\r?\n/u)
    .map((line) => line.trim()).filter((line) => line && !line.startsWith("#"));
  const requiredByPath = new Map(requiredLines.map((line) => [line.split(" ")[0], line]));
  for (const requiredLine of requiredLines) {
    if (lines.filter((line) => line === requiredLine).length !== 1) {
      throw new Error(`Source archive must pin ${requiredLine} exactly once.`);
    }
  }
  for (const line of lines) {
    if (disjointWildcardRules.has(line)) continue;
    const [pattern, ...attributes] = line.split(/\s+/u);
    if (!/^[A-Za-z0-9_.-]+(?:\/[A-Za-z0-9_.-]+)*$/u.test(pattern)
        || pattern.split("/").some((part) => part === "." || part === "..")
        || attributes.length === 0
        || attributes.some((attribute) => !/^(?:-?text|-?whitespace|eol=(?:lf|crlf))$/u.test(attribute))) {
      throw new Error(`Unsupported source archive attribute rule; wildcard or noncanonical overrides are rejected: ${line}`);
    }
    const canonicalLine = requiredByPath.get(pattern);
    if (canonicalLine && line !== canonicalLine) {
      throw new Error(`Source archive attribute override for pinned resource ${pattern} is rejected.`);
    }
  }
  const checkedDirectories = new Set();
  for (const resourcePath of requiredByPath.keys()) {
    let directory = dirname(resourcePath);
    while (directory !== ".") {
      if (!checkedDirectories.has(directory)) {
        checkedDirectories.add(directory);
        if (optionalRegularFile(join(workspace, directory, ".gitattributes"))) {
          throw new Error(`Nested source archive attribute overrides are rejected: ${directory}/.gitattributes`);
        }
      }
      directory = dirname(directory);
    }
  }
}
