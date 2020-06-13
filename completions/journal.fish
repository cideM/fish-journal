# List all commands, useful for the -n option of the complete function
set -l commands tags search titles

# Disable file completion
complete -c journal -f

# Command completion
complete -c journal -n "not __fish_seen_subcommand_from $commands" -a "tags" -d "list all tags" 
complete -c journal -n "not __fish_seen_subcommand_from $commands" -a "titles" -d "list all titles" 
complete -c journal -n "not __fish_seen_subcommand_from $commands" -a "search" -d "search journal entries" 

# Switch/options completion
complete -c journal -s t -l tags -a "(journal tags)" -d "Tags"
complete -c journal -s T -l title -a "(journal titles)" -d "Title"
complete -c journal -s f -l "filename-only" -n "__fish_seen_subcommand_from search" -d "list only filenames"

