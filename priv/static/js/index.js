var ws;
var game_id;
var username;
var dealt = false;
var card;

function draw(html) {
    $("#game-msg").html("");
}

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
            case "update":
                update_game(data);
                break;
            case "gameover":
                if (data.winner == username) {
                    $("#game-msg").html("<strong>You win!!!</strong>");
                } else {
                    $("#game-msg").html("<strong>You loose :'(</strong>");
                }
                break;
        }
    };
}

function start_game(data) {
    dealt = true;
    $("#onBoardingModal").modal('hide');
    $("#dealingModal").modal('hide');
    update_game(data);
}

function update_game(data) {
    var html = data.players.reduce(function(html, player) {
        var player_name = player.username;
        if (player_name == username) {
            player_name += " (you)";
        }
        if (data.turn == player.username && data.turn == username) {
            html += "<tr class='table-success'><td>" + player_name + "</td>";
        } else {
            html += "<tr><td>" + player_name + "</td>";
        }
        html += "<td>" + player.num_cards + "</td></tr>";
        return html;
    }, "");
    $("#list-players").html(html);
    $("#game-color span").html(data.shown_color);
    $("#card-shown").attr("src", data.shown[1]);
    html = data.hand.reduce(function(acc, card) {
        if (card[0] == "special") {
            return [acc[0] + 1, acc[1] + "<img src='" + card[1] + "' id='play-" + acc[0] + "' class='card special'/>"];
        }
        return [acc[0] + 1, acc[1] + "<img src='" + card[1] + "' id='play-" + acc[0] + "' class='card'/>"];
    }, [1, ""]);
    $("#game-hand-cards").html(html[1]);
    $(".card").on("click", function(){
        card = parseInt($(this).attr("id").split("-")[1]);
        if ($(this)[0].classList.contains("special")) {
            $("#changeColorModal").modal('show');
        } else {
            send({type: "play", card: card, color: "red"});
        }
    });
    $("#chooseColor").on("click", function(){
        var color = $("input:radio[name=color]:checked").val();
        send({type: "play", card: card, color: color});
        $("#changeColorModal").modal('hide');
    });
    $("#game-deck span").html(data.deck);
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

function set_game_id(id) {
    game_id = id;
    var url = new URL(document.URL);
    url.pathname = "/" + game_id;
    var web_url = url.toString();
    url.pathname = "/qr/" + game_id;
    var qr_url = url.toString();
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
    $("#game-restart").on("click", function(event) {
        send({type: "restart"});
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
