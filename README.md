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
 


