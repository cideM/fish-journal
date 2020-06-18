# Journaling For Fun And Simplicity in :fish:

I wanted to reimplement a smallish subset of `jrnl` in Fish shel. I then ran into a big issue which is that BSD `date` (on MacOS) doesn't have the `-d` flag, or rather, it doesn't do what it does on GNU. And that makes it really hard to get the same functionality. I don't want to reimplement `date` handling, obviously, so I stopped working on this.
