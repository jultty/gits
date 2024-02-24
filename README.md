# gits

A cleaner and friendlier alternative to `git status`.

`gits` provides an output similar to `git status --porcelain`, but with branch information by default, less cryptic messages for yet untracked or mid-rebase statuses and colored output.

While gits' porcelain commands are explicitly _meant_ to change and not be used for scripting, note that this tool does not and will not perform any writing operations. Rather, it only reads and parses the output from `git status --porcelain --branch`. Any other calls it makes to git are also read-only and seek information that git does not provide in its porcelain status during certain occasions.

The output, as in `git status --porcelain`, uses certain characters to represent the status of files:.

```
? = untracked
M = modified
A = added
D = deleted
R = renamed
U = updated but unmerged
```

See `git status --help`for an extensive list of other such characters and the possible combinations across both columns.

## Development

This OCaml tool compiles directly from a single file for now. There are no external dependencies other than the standard library's Unix and Sys modules.

All you need is a working [OCaml environment](https://ocaml.org/install) and, of course, Git. The current version of Git used for development is 2.39.2.

The `build.sh` script provides an easy way to resolve imports and build a binary.
