#!/bin/bash

ERLANG_VSN=22.0
ELIXIR_VSN=1.8.2

./build_package.sh
#docker run -it --rm \
#           -v $(pwd):/dymmer \
#           -w /dymmer \
#           altenwald/phoenix:otp${ERLANG_VSN}_ex${ELIXIR_VSN} ./build_package.sh
