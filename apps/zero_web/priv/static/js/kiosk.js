var ws;
var game_id;
var timer;
var deck = "timmy";

function change_deck(from, to) {
  $("img").each(function (i, e) {
      var attr = $(e).attr("src");
      if (attr.startsWith("/img/cards/" + from)) {
          var pngfile = attr.split("/").reverse()[0];
          $(e).attr("src", "/img/cards/" + to + "/" + pngfile);
      }
  });
}

function set_game_id(id) {
  game_id = id;
  var web_url = get_url_base("/" + game_id);
  var qr_url = get_url_base("/qr/" + game_id);
  var kiosk_url = get_url_base("/kiosk/" + game_id);
  $("#modal-players-url").attr("href", web_url);
  $("#modal-players-url").html(web_url);
  $("#modal-players-url-img").attr("src", qr_url);
  history.pushState({id: game_id}, "Zero Game", kiosk_url);
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

function get_url_base(new_uri = "/kiosk") {
  var url = new URL(document.URL);
  url.pathname = new_uri;
  return url.toString();
}

function start_game(data) {
  $("#dealingModal").modal('hide');
  $("#gameOverModal").modal('hide');
  $("#log").html("");
  update_game(data);
}

function update_players_table(players) {
  var html = players.reduce(function(html, player) {
      var player_name = player.username;
      html += "<tr><td>" + player_name + "</td>";
      html += "<td>" + player.num_cards + "</td></tr>";
      return html;
  }, "");
  $("#list-players").html(html);
}

function update_hiscore(players) {
  var html;
  for (var player in players) {
    html += "<tr><td>" + player + "</td>";
    html += "<td>" + players[player] + "</td></tr>";
  }
  $("#list-hiscore").html(html);
  $("#list-hiscore-gameover").html(html);
}

function update_shown_card(data) {
  $("#game-color span").html(data.shown_color);
  $("#card-shown").attr("src", data.shown[1]);
}

function update_deck(deck) {
  $("#game-deck span").html(deck);
}

function update_game(data) {
  update_players_table(data.players);
  update_shown_card(data);
  update_deck(data.deck);
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
  if (ws) {
    ws.close();
  }
  var url = new URL(document.URL);
  var schema = (url.protocol == "https:") ? "wss" : "ws";
  ws = new WebSocket(schema + "://" + url.host + "/kiosksession");
  ws.onopen = function(){
    var uri = url.pathname;
    console.log("connected!");
    switch (uri) {
      case "/kiosk":
      case "/kiosk/":
        send({type: "create"});
        break;
      default:
        var parts = uri.split("/");
        set_game_id(parts[parts.length-1]);
        send({type: "listen", name: game_id});
    }
    send({type: "deck", name: deck});
    $("#dealingModal").modal('show');
    $("#game-msg").html("");
    if (timer) {
      clearInterval(timer);
    }
    timer = setInterval(function(){
      send({type: "ping"});
    }, 10000);
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
        update_hiscore(data.hiscore);
        break;
      case "leave":
        clear_player(data.username);
        break;
      case "id":
        set_game_id(data.id);
        if (data.players) {
          clean_players();
          for (var i=0; i<data.players.length; i++) {
            update_player(data.players[i].username);
          }
        }
        $("#onBoardingModal").modal('show');
        break;
      case "vsn":
        $("#vsn").html("v" + data.vsn);
        break;
      case "dealt":
        start_game(data);
        break;
      case "turn":
      case "pick_from_deck":
        update_game(data);
        break;
      case "hiscore":
        update_hiscore(data.hiscore);
        $("#hiscoreModal").modal('show');
        break;
      case "game_over":
        update_hiscore(data.hiscore);
        update_shown_card(data);
        update_players_table(data.players);
        $("#game-over-msg").html(data.winner + " won!");
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
          add_event_msg("starts the game!");
          break;
      case "turn":
          if (data.shown_color != $("#game-color span").html()) {
              add_event_msg(data.previous + " changed to " + data.shown_color);
          }
          var msg_color = "blue";
          add_event_msg(data.turn + "'s turn", msg_color);
          break;
      case "pick_from_deck":
          add_event_msg("oh! " + data.turn + " had to pick one card from deck!");
          break;
      case "gameover":
          add_event_msg(data.winner + " wins!");
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
          add_event_msg("sadly " + data.previous + " couldn't use any card!");
          break;
      case "reverse":
          add_event_msg(data.previous + " reversed the turns! what a mess!");
          break;
  }
}

$(document).ready(function(){
  connect();
  $("#game-pick").on("click", function(event) {
    event.preventDefault();
    send({type: "pick-from-deck"});
  });
  $("#game-pass").on("click", function(event) {
    event.preventDefault();
    send({type: "pass"});
  });
  $("#game-hiscore").on("click", function(event) {
    event.preventDefault();
    send({type: "hiscore"});
  });
  $("#deck-timmy").on("click", function(event) {
    event.preventDefault();
    var old_deck = deck;
    deck = "timmy";
    change_deck(old_deck, deck);
    send({type: "deck", name: deck});
  });
  $("#deck-uno").on("click", function(event) {
    event.preventDefault();
    var old_deck = deck;
    deck = "uno";
    change_deck(old_deck, deck);
    send({type: "deck", name: deck});
  });
  $("#bot-add").on("click", function(event){
    event.preventDefault();
    send({type: "bot", name: $("#bot-name").val()});
    $("#bot-name").val("");
  });
  $("#bot-name").on("keydown", function(event) {
    var keyCode = event.keyCode || event.which;
    if (keyCode == 13) {
      $("#bot-add").trigger("click");
      return false;
    }
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
