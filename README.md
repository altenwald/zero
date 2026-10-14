# Zero

Zero Cards Game... yes, it's similar to Uno&trade; but I don't like to say "Uno" when only remains a card in my hand.

If you love this content and want we can generate more, you can support us:

[![paypal](https://www.paypalobjects.com/en_US/GB/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=RC5F8STDA6AXE)

## Getting Started

You need Erlang/OTP 29 and Elixir 1.20. Start the game server (port 4015, or the one in `PORT`):

```
mix deps.get
mix run --no-halt
```

Open <http://localhost:4015/> to play from the browser; `/kiosk` shows the board on a big screen while the players use their own devices.

To play in the terminal, start the node with a name and, from another terminal, connect to it:

```
iex --sname zero@localhost --cookie zerogame -S mix run
iex --sname zero2@localhost --cookie zerogame --remsh zero@localhost
```

At this point both consoles are connected to the same node in different processes so, you can run `ZeroConsole.start` in both of them and follow the instructions.

## Release

```
./build.sh
_build/prod/rel/zero/bin/zero start
```

`bin/zero remote` opens a shell on the running release and `:observer_cli.start()` shows what it is doing. The repository includes `dymploy.yaml` to build and deploy it with [dymploy](https://github.com/dymmer-code/dymploy).

## Development

`mix check` runs the formatter, credo, dialyzer, the tests and the dependency audit (see `.check.exs` if you want to adjust it).

Enjoy!
