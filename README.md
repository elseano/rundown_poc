# Rundown

Turns markdown files into amazing executable documentation.

Usage:

```
rundown execute SETUP.md
```

## Supports

* Renders all markdown blocks
* Runs code blocks as they're encountered, displaying an activity indicator
* Supports running any kind of markdown code block
* Supports idempotent execution via special test code blocks

## Example

Rundown really shines when you've got a markdown file which you generally need to copy and paste from to run commands.

<pre>
# Acme Project setup instructions

In order to develop Acme, install homebrew.

``` bash
brew install homebrew
```

Then install all the NodeJS packages.

``` bash
npm install
```

Initialise your database

``` bash skip_on_success
./scripts/show_db_stats
```

``` bash
./scripts/init_db
```

## Hooking into Widgets

In order to hook Acme into Widgets, you'll need to update your Widgets config file

``` ruby rundown
path = Pathname.new(ENV["HOME"]) / ".widgets" / "config"
ini = IniFile.load(path)
ini['plugins']['acme'] = `pwd`.strip
ini.save
```

# Done

All done. Run `./scripts/start` when ready.

</pre>

Running markdown with this file, you'll get an output similar to the below (omitting all the pretty colours and indicators)

```
$ rundown execute SETUP.md

Acme Project Setup instructions

In order to develop Acme, install homebrew.

Then install all the NodeJS packages.

Initialise your database

. . . .

  Hooking into Widgets
  
  In order to hook Acme into Widgets, you'll need to update your Widgets config file
  
  .
  
Done

  All done. Run `./scripts/start` when ready.

```

The `.` indicate completed code blocks. During runtime, the output would reveal itself upto the currently executing codeblock. For example, as Homebrew is being installed, you wouldn't see anything under "install homebrew".
 

## Code Blocks

Code blocks in Markdown support specifying the interpreter:

<pre>
``` ruby
puts "Hi"
```
</pre>

Any interpreter available within your `PATH` is supported. If no interpreter is specified, `sh` is used.

By default, code blocks are not shown, however running with the `--verbose` option will show code blocks before they're executed.

If a code block returns a **non-zero** exit code, the run is aborted and `STDERR` is displayed.

### Modifiers

Code block modifiers are supported which change how the block operates. Any number of modifiers can be specified after the interpreter.

``` ruby interactive
print "Enter your name: "
name = gets
puts "Hi #{name}"
```

The following modifiers are supported:

* `interactive` - Show STDOUT and STDERR, and expect input from STDIN. Handy for scripts which might ask for a password, etc.
* `skip_on_success` - Skip the remaining code and content until the next heading if the script exits with a **zero** error code.
* `skip_on_failure` - Skip the remaining code and content until the next heading if the script exits with a **non-zero** error code.
* `runbook` - Only works with the `ruby` interpreter. Runs the code inside the running Runbook process, which gives you access to utilities as described below.
* `nospin` - Don't show the activity spinner. 
* `display_only` - Don't run the code block, instead display it.
* `reveal` - Show the STDOUT of the running codeblock.

The modifiers `skip_on_success` and `skip_on_failure` are great guards to prevent taking an action twice, and can speed up repeated executions.

### Runbook Utilities

When using `ruby` with the `runbook` modifier, you'll have access to the libraries included with Runbook:

* `prompt` - An instance of TTY::Prompt, for asking questions.
* `Inifile` - The Inifile Gem for reading and manipulating `.ini` files.



