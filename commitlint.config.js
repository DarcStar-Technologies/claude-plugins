// Commit message linting for the DarcStar plugin marketplace.
// Enforces Conventional Commits so that release-please can derive semver bumps
// and generate changelogs automatically.
//
// Format:  <type>(<scope>): <subject>
//   type   one of the list below
//   scope  a plugin name (e.g. "_template") or a repo area ("ci", "scripts",
//          "docs", "release"). Optional but strongly encouraged.
//
// Examples:
//   feat(my-plugin): add /summarize command
//   fix(scripts): handle plugins with no components
//   feat(my-plugin)!: rename the primary command   (! => major bump)
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [
      2,
      'always',
      [
        'feat',
        'fix',
        'docs',
        'refactor',
        'perf',
        'test',
        'build',
        'ci',
        'chore',
        'revert',
      ],
    ],
    // Documentation lines (changelog snippets, URLs) can exceed 100 columns.
    'body-max-line-length': [0, 'always'],
    'footer-max-line-length': [0, 'always'],
  },
};
