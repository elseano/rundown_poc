# Acme Project setup instructions

This is a Rundown demo script, showing the features of rundown.

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