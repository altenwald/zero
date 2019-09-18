var ws;
var game_id;
var username;
var dealt = false;
var refresh_hand = false;
var card;

function disconnected(should_i_reconnect) {
    if (should_i_reconnect) {
        $("#game-msg").html("<strong>¡Disconnected! Reconnecting...</strong>");
        setTimeout(function(){ connect(); }, 1000);
    } else {
        $("#game-msg").html("<strong>¡Disconnected!</strong>");
    }
}

function send(message) {
    console.log("send: ", message);
    ws.send(JSON.stringify(message));
};

function connect() {
    const hostname = document.location.href.split("/", 3)[2];
    if (ws) {
        ws.close();
    }
    var schema = (location.href.split(":")[0] == "https") ? "wss" : "ws";
    ws = new WebSocket(schema + "://" + hostname + "/websession");
    ws.onopen = function(){
        var parts = new URL(document.URL);
        var uri = parts.pathname;
        console.log("connected!");
        switch (uri) {
            case "/":
                send({type: "create"});
                break;
            default:
                set_game_id(uri.slice(1));
        }
        if (!username) {
            $("#onBoardingModal").modal('show');
            $("#dealingModal").modal('hide');
        } else {
            clean_players();
            send({type: "join", name: game_id, username: username});
            $("#onBoardingModal").modal('hide');
            if (!dealt) {
                $("#dealingModal").modal('show');
            } else {
                $("#dealingModal").modal('hide');
            }
        }
        $("#game-msg").html("");
    };
    ws.onerror = function(message){
        console.error("onerror", message);
        disconnected(false);
    };
    ws.onclose = function() {
        console.error("onclose");
        disconnected(true);
    }
    ws.onmessage = function(message){
        console.log("Got message", message.data);
        var data = JSON.parse(message.data);
        process_event_msg(data);
        switch(data.type) {
            case "join":
                update_player(data.username);
                break;
            case "leave":
                clear_player(data.username);
                break;
            case "id":
                set_game_id(data.id);
                $("#onBoardingModal").modal('show');
                break;
            case "vsn":
                $("#vsn").html("v" + data.vsn);
                break;
            case "dealt":
                start_game(data);
                break;
            case "turn":
                if (data.turn == username) {
                    update_game(data);
                } else {
                    if (data.previous == username && refresh_hand) {
                        update_hand(data.hand);
                    }
                    update_players_table(data.players, data.turn);
                    update_shown_card(data);
                }
                break;
            case "pick_from_deck":
                if (data.turn == username) {
                    update_game(data);
                } else {
                    update_players_table(data.players, data.turn);
                    update_deck(data.deck);
                }
                break;
            case "gameover":
                if (data.winner == username) {
                    $("#game-over-msg").html("You win!!!");
                } else {
                    $("#game-over-msg").html("You loose :'(");
                }
                $("#gameOverModal").modal('show');
                break;
            case "notfound":
                location.href = get_url_base();
                break;
        }
    };
}

function add_event_msg(msg, color) {
    if (!color) {
        $("#log").prepend("<li>" + msg + "</li>");
    } else {
        var class_name = "table-danger";
        switch (color) {
            case "green": class_name = "table-success"; break;
            case "blue": class_name = "table-info"; break;
            case "yellow": class_name = "table-danger"; break;
        }
        $("#log").prepend("<li class='" + class_name + "'>" + msg + "</li>");
    }
}

function process_event_msg(data) {
    switch (data.type) {
        case "dealt":
            if (!dealt) {
                add_event_msg("starts the game!");
            }
            break;
        case "turn":
            if (data.shown_color != $("#game-color span").html()) {
                add_event_msg(data.previous + " changed to " + data.shown_color);
            }
            var msg_color = "blue";
            if (data.turn == username) {
                msg_color = "green";
            }
            add_event_msg(data.turn + "'s turn", msg_color);
            break;
        case "pick_from_deck":
            add_event_msg("oh! " + data.turn + " had to pick one card from deck!");
            break;
        case "gameover":
            if (data.winner == username) {
                add_event_msg("you beat your opponents! well done!");
            } else {
                add_event_msg("well, best luck next time, " + data.winner + " wins!");
            }
            break;
        case "plus_2":
            add_event_msg(data.previous + " gives some love and +2 cards to " + data.turn);
            break;
        case "plus_4":
            add_event_msg(data.previous + " gives some love and +4 cards to " + data.turn);
            break;
        case "lose_turn":
            add_event_msg(data.previous + " gives some rest to " + data.skipped);
            break;
        case "pass":
            if (data.previous == username) {
                add_event_msg("don't worry, you can! next time you could use your cards!");
            } else {
                if (data.turn == username) {
                    add_event_msg("you have an opportunity! " + data.previous + " passed!");
                } else {
                    add_event_msg("sadly " + data.previous + " couldn't use any card!");
                }
            }
            break;
        case "reverse":
            add_event_msg(data.previous + " reversed the turns! what a mess!");
            break;
    }
}

function start_game(data) {
    dealt = true;
    $("#onBoardingModal").modal('hide');
    $("#dealingModal").modal('hide');
    $("#gameOverModal").modal('hide');
    $("#log").html("");
    update_game(data);
}

function update_players_table(players, turn) {
    var html = players.reduce(function(html, player) {
        var player_name = player.username;
        if (player_name == username) {
            player_name += " (you)";
        }
        if (turn == player.username && turn == username) {
            html += "<tr class='table-success'><td>" + player_name + "</td>";
        } else {
            html += "<tr><td>" + player_name + "</td>";
        }
        html += "<td>" + player.num_cards + "</td></tr>";
        return html;
    }, "");
    $("#list-players").html(html);
}

function update_shown_card(data) {
    $("#game-color span").html(data.shown_color);
    $("#card-shown").attr("src", data.shown[1]);
}

function update_hand(hand) {
    html = hand.reduce(function(acc, card) {
        if (card[0] == "special") {
            return [acc[0] + 1, acc[1] + "<img src='" + card[1] + "' id='play-" + acc[0] + "' class='card special'/>"];
        }
        return [acc[0] + 1, acc[1] + "<img src='" + card[1] + "' id='play-" + acc[0] + "' class='card'/>"];
    }, [1, ""]);
    $("#game-hand-cards").html(html[1]);
    refresh_hand = false;
    $(".card").on("click", function(){
        card = parseInt($(this).attr("id").split("-")[1]);
        if ($(this)[0].classList.contains("special")) {
            $("#changeColorModal").modal('show');
        } else {
            refresh_hand = true;
            send({type: "play", card: card, color: "red"});
        }
    });
}

function update_deck(deck) {
    $("#game-deck span").html(deck);
}

function update_game(data) {
    update_players_table(data.players, data.turn);
    update_shown_card(data);
    update_hand(data.hand);
    update_deck(data.deck);
    $("#game-msg").html("");
}

function update_player(username) {
    var slug = slugify(username);
    $("#modal-players").append("<li id='" + slug + "'>" + username + "</li>");
}

function clear_player(username) {
    var slug = slugify(username);
    $("#" + slug).remove();
}

function clean_players() {
    $("#modal-players").html("");
}

function get_url_base(new_uri = "/") {
    var url = new URL(document.URL);
    url.pathname = new_uri;
    return url.toString();
}

function set_game_id(id) {
    game_id = id;
    var web_url = get_url_base("/" + game_id);
    var qr_url = get_url_base("/qr/" + game_id);
    $("#modal-players-url").attr("href", web_url);
    $("#modal-players-url").html(web_url);
    $("#modal-players-url-img").attr("src", qr_url);
    history.pushState({id: game_id}, "Zero Game", web_url);
}

$(document).ready(function(){
    connect();
    $("#join").on("click", function(event) {
        var user = $("#username").val();
        $("#onBoardingModal").modal('hide');
        $("#dealingModal").modal('show');
        username = user;
        send({type: "join", name: game_id, username: user});
    });
    $("#deal").on("click", function(event) {
        send({type: "deal"});
    });
    $("#game-pick").on("click", function(event) {
        send({type: "pick-from-deck"});
    });
    $("#game-pass").on("click", function(event) {
        send({type: "pass"});
    });
    $("#chooseColor").on("click", function(){
        var color = $("input:radio[name=color]:checked").val();
        refresh_hand = true;
        send({type: "play", card: card, color: color});
        $("#changeColorModal").modal('hide');
    });
    $("#chooseColorCancel").on("click", function(){
        $("#changeColorModal").modal('hide');
    });
    $("#game-over-new").on("click", function(){
        send({type: "stop"});
        location.href = get_url_base();
    });
    $("#game-over-restart").on("click", function(){
        send({type: "restart"});
        $("#gameOverModal").modal('hide');
    });
    $("#bot-add").on("click", function(){
        send({type: "bot", name: $("#bot-name").val()});
    });
});

// from: https://gist.github.com/hagemann/382adfc57adbd5af078dc93feef01fe1#file-slugify-js
function slugify(string) {
    const a = 'àáäâãåăæąçćčđďèéěėëêęğǵḧìíïîįłḿǹńňñòóöôœøṕŕřßşśšșťțùúüûǘůűūųẃẍÿýźžż·/_,:;"\''
    const b = 'aaaaaaaaacccddeeeeeeegghiiiiilmnnnnooooooprrsssssttuuuuuuuuuwxyyzzz--------'
    const p = new RegExp(a.split('').join('|'), 'g')
  
    return string.toString().toLowerCase()
      .replace(/\s+/g, '-') // Replace spaces with -
      .replace(p, c => b.charAt(a.indexOf(c))) // Replace special characters
      .replace(/&/g, '-and-') // Replace & with 'and'
      .replace(/[^\w\-]+/g, '') // Remove all non-word characters
      .replace(/\-\-+/g, '-') // Replace multiple - with single -
      .replace(/^-+/, '') // Trim - from start of text
      .replace(/-+$/, '') // Trim - from end of text
}
