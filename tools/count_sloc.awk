/^[ \t]*\/\*/ , /\*\/[ \t]*$/ { next } # Skip /* ... */ comments
/^ *$/ || /^ *\/\// { next } # Skip empty and //comment-only lines
{ sloc++ }
END { print sloc }
