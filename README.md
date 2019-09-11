# Zero

Zero Cards Game... yes, it's similar to Uno&trade; but I don't like to say "Uno" when only remains a card in your hand.

If you love this content and want we can generate more, you can support us:

[![paypal](https://www.paypalobjects.com/en_US/GB/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com
/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=RC5F8STDA6AXE)

## Getting Started

It's easy, you only needs to download the source code and ensure you have installed Erlang and Elixir. Then you can open two terminals and in one of them:

```
iex --sname zero@localhost --cookie zerogame -S mix run
```

And in the other terminal:

```
iex --sname zero2@localhost --cookie zerogame --remsh zero@localhost
```

At this point both consoles are connected to the same node in different processes so, you can run:

```
Zero.start
```

For both terminals and following the instructions.

A sample about how to play:

[![Playing Zero](playing_zero.gif)](playing_zero.gif)

Enjoy!
