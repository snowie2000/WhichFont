# WhichFont
This little app hooks the application and gives a dynamic list of all the fonts it is currently using.

# Usage
Launch the executable and select a `.exe` file to start.

MacType must be disabled before start.

Only x86 applications are currently supported. It should work for x64 too without any source code modification. It just hasn't been done yet.

It only traces the program you selected, the child processes it creates won't be captured.

It only traces the fonts the program is drawing texts with, not the fonts the program created.
