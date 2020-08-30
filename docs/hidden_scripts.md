# Hidden Scripts example

Rundown allows you to specify hidden scripts within your markdown files. These hidden scripts are handy for the purposes of cleaning up the documentation when you want to prompt for input, or test that something doesn't need to be done.

## Hidden Script - Checking if it should run

<!--~
``` bash skip_on_success named
# Checking to see if I should run
true
```
-->

``` bash named
# Install the thing
sleep 1
```

## Hidden Prompting Script

The hidden prompting script allows you to capture information and export that information as environment variables to subsequent code blocks. Anything written out to STDOUT as "KEY=value" will be captured, and automatically provided to subsequent scripts.

``` bash capture_env interactive
read -p "${STDOUT_PREFIX}Enter your name: " NAME
echo "rundown set NAME=$NAME"
```

``` ruby display_output
puts "Your name is: #{ENV["NAME"]}"
```

Hidden scripts can also capture. Enter your favourite color:

<!--~
``` bash capture_env interactive
read -p "${STDOUT_PREFIX}Enter your favourite color: " COL
echo "rundown set COL=$COL"
```
-->

``` ruby display_output
puts "Your color is: #{ENV["COL"]}"
```

Once `rundown` is finished, the environment variables set during the script don't pollute your shell session.

## Hidden Scripts with Titles

Hidden scripts can have titles as well

<!--~
``` bash named
# Articulating spines...
sleep 1
```
-->

Done.