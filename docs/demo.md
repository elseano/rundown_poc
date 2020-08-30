# Acme Project setup instructions

This is a Rundown demo script, showing the features of rundown.

# Asking Questions

Using the Ruby Rundown script mode.

``` ruby rundown nospin
name = prompt.ask("What is your #{color.bold("Name")}?") { |p| p.required }
add_env("NAME", name)
```

## Another Question

Indenting is supported within shell script output. Some tools don't play nice, so there's always the `STDOUT_PREFIX` environment variable you can inject.

Note the `capture_env` and `interactive` modifiers.

``` bash capture_env interactive
read -p "${STDOUT_PREFIX}What is your favourite color? " COL
echo "rundown set COL=$COL"
```

``` ruby rundown
$trap=false
true
```

### Your results

Now you can reference these things from the environment.


``` bash display_output
echo "Your name is $NAME"
echo "Your favourite color is $COL"
```

# Example project setup

In order to develop Acme, install `homebrew`.

``` bash named display
# Installing Homebrew...
sleep 1
```

Then install all the NodeJS packages.

``` bash named display
# Installing NodeJS...
sleep 1
```

Initialise your database

``` bash named display
# Checking database is setup...
sleep 1
```

``` bash named display
# Setting up database...
sleep 1
```

Fix errors

``` bash named skip_on_success display
# Checking for errors...
sleep 1
```

``` bash
We will never get here.
```


## Hooking into Widgets

In order to hook Acme into Widgets, you'll need to update your Widgets config file

``` ruby rundown
sleep(1)
```

## Setting up environment

Environment variables can be set for future scripts by printing a special command to STDOUT, in the form of `set rundown KEY=VALUE`.

``` ruby rundown
$trap=false
true
```

``` bash named capture_env
# Grabbing env stuff
echo "rundown set SOME_ENV=Hi there from a script!"
```

Now that I have them, I can reference them in later scripts:


``` bash reveal nospin
echo "I set the environment variable SOME_ENV to $SOME_ENV"
```


# Done

All done. Run `./scripts/start` when ready.