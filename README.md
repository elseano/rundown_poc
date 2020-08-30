# Rundown

Turns markdown files into amazing executable documentation.

Usage:

```
rundown SETUP.md
```

<img src="https://github.com/elseano/rundown/raw/master/docs/preview.png">

For more examples, check out the `docs` folder.


## Supports

* Renders all markdown blocks
* Runs code blocks as they're encountered, displaying an activity indicator
* Supports running any kind of markdown code block
* Supports idempotent execution via special test code blocks

## Example

<img src="https://github.com/elseano/rundown/raw/master/docs/runbook.gif">

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

The `.` indicate completed code blocks, while `x` indicates failure, and `-` indicates skipped. 
 

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

Code block modifiers are supported which change how the block operates. Any number of modifiers can be specified, and there are several ways to specify them depending on the markdown engine you're using to render the file.

**Option 1** straight after the language specification. Works with GitHub.

    ``` ruby interactive
    print "Enter your name: "
    name = gets
    puts "Hi #{name}"
    ```

**Option 2** as a empty link. Works with Github and a few other renderers.

    [](interactive)
    ``` ruby
    print "Enter your name: "
    name = gets
    puts "Hi #{name}"
    ```

**Option 3** as XML comments

    <!--~ interactive -->
    ``` ruby
    print "Enter your name: "
    name = gets
    puts "Hi #{name}"
    ```


The following modifiers are supported:

* `interactive` - Show STDOUT and STDERR, and expect input from STDIN. Handy for scripts which might ask for a password, etc.
* `skip_on_success` - Skip the remaining code and content until the next heading if the script exits with a **zero** error code.
* `skip_on_failure` - Skip the remaining code and content until the next heading if the script exits with a **non-zero** error code.
* `rundown` - Only works with the `ruby` interpreter. Runs the code inside the running Rundown process, which gives you access to utilities as described below.
* `nospin` - Don't show the activity spinner. Automatically activated when `interactive`, `reveal_script_only`, or `reveal_script` specified. Setting this causes `named` to have no effect.
* `reveal_script_only` - Don't run the code block, instead display it.
* `reveal_script` - Run and display the block.
* `display_output` - Show the STDOUT of the running codeblock.
* `capture_env` - Any line in STDOUT of the format `rundown set $KEY=$VALUE` will be used to set environment `$KEY` to `$VALUE` in subsequent scripts.
* `named` - The first line of the script should be a comment, and the comment text will be used as the spinner text while executing.

The modifiers `skip_on_success` and `skip_on_failure` are great guards to prevent taking an action twice, and can speed up repeated executions.

### Rundown Utilities

When using `ruby` with the `rundown` modifier, you'll have access to the libraries included with Rundown:

* `prompt` - An instance of TTY::Prompt, for asking questions.
* `Inifile` - The Inifile Gem for reading and manipulating `.ini` files.


### Interactive Mode

Use this if your script will be asking for input from the user. Rundown sets some utility environment variables to keep the display consistent. Interactive mode automatically sets `nospin`.

* `STDOUT_PREFIX` - A string of indent spaces and script output marker.

For example:

    ``` bash interactive
    read -p "${$STDOUT_PREFIX}Hi there. Whats your name? " NAME
    ```

Generally, you'll want to use `interactive` mode with hidden scripts, so your documentation cleanly shows the manual steps readers can take, but when running using Rundown they get extra goodness.

### Hidden Scripts

Hidden scripts are a great method to keep your documentation clean for readers, while allowing you to take extra steps when running under Rundown.

Hidden scripts are simply fenced code blocks within an XML comment. To denote a hidden script, add a tilde `~` to the `<!--` marker:

    <!--~
    ``` bash interactive
    read -p "${STDOUT_PREFIX}Whats your email address? " EMAIL
    ```
    -->

    Setup Git as follows:

    ``` bash
    git config --global "user.email" $EMAIL
    ```

## Logging

Rundown runs are logged automatically into `~/.rundown/$FILE.log`, where $FILE is the filename of your markdown file being run. You can change the logfile location using the `--log $FILENAME` command line argument.

## Todo

Rundown is currently under development. It's good for general use, but there's some features still to add:

* [ ] Clean up the `ruby` with `rundown` API.
* [ ] Clean up the CLI output.
* [ ] Homebrew formula for installation (possibly with TravellingRuby)
* [ ] Gemspec to allow installation from the `gem` command.
* [ ] Support directly invoking specific parts of the file (and/or an option menu)
* [ ] Support running a markdown file from STDIN to make executable scripts
* [ ] Test suite
* [ ] Fix word wrapping (broken upstream tty-markdown)
* [ ] Automatic links (broken upstream tty-markdown)
* [ ] Work out how to redirect STDOUT in interactive mode cleanly (broken upstream tty-command) 

If you're using Rundown, let me know! Feel free to add issues and questions.
