

/* eslint-disable no-console */
function switchMenus() {
  const reg = document.getElementsByClassName('regqq');
  const signup = document.getElementsByClassName('signupqq');
  reg[0].classList.toggle('hidden');
  signup[0].classList.toggle('hidden');
}

function showError(p) {
  // eslint-disable-next-line no-alert
  alert(p);
}

/**
 * Отправляет formdata на указанные адрес
 * @param {string} url адрес для post запроса
 * @param {FormData} formdata  что отправлять
 * @returns {Promise<Response>}
 * @throws при ошибке сети
 */

/*
запрашиваем данные с сервера, обещает вернуть ответ
*/
async function postFormdata(url, formdata) {
  return fetch(url, { method: 'POST', body: formdata });
}

/**
 * Красиво печатает ответ от сервера с таймаутом
 * @param {any=} data полученный ответ от сервера
 * @param {number=} timeout таймаут для сообщения, 0 - без таймаута
 */
function statusHandler(data, timeout = 5000) {
  if (typeof data === 'undefined' || Object.keys(data).length < 1) {
    document.querySelector('#err').innerHTML = '';
    return;
  }
  document.querySelector('#err').innerHTML = `<span><b>${Object.keys(data)[0]}</b> ${Object.keys(data)[1]}<span>`;
  if (timeout > 0) {
    setTimeout(statusHandler, timeout);
  }
}

function createGameWindow() {
  const gc = document.querySelector('.gamecreateqq');
  const ent = document.querySelector('#cont');
  ent.classList.toggle('hidden');
  gc.classList.toggle('hidden');
}

async function leaveGame() {
  clearTimeout(stateTimeout);
  const fd = new FormData();
  fd.set('db', '3396'); // указываем бд
  fd.set('pname', 'leave_game'); // указываем процедуру из sql
  fd.set('p1', sessionStorage.getItem('login')); // указываем первый параметр, который передается в процедуру в sql
  fd.set('p2', sessionStorage.getItem('pw')); // указывает второй параметр
  try {
    await (await postFormdata('https://play.lavro.ru/call.php', fd)) // ждем результата запроса
      .json(); // ждем json
    document.querySelector('#current-game').classList.add('hidden');
    document.querySelector('#cont').classList.toggle('hidden');
  } catch (e) {
    showError(e);
    console.error(e);
  }
}

function createWaitingForGameView(data) {
  document.querySelector('#enter').classList.add('hidden');
  const statusContainer = document.createElement('div');

  const gameInfoSpan = document.createElement('span');
  gameInfoSpan.innerText = `Game #${data.waiting_for_players[0]}`;

  const leaveButton = document.createElement('a');
  leaveButton.innerText = 'Leave';
  leaveButton.addEventListener('click', () => { leaveGame(); });
  leaveButton.classList.add('update');

  statusContainer.appendChild(gameInfoSpan);
  statusContainer.appendChild(leaveButton);

  const playerContainer = document.createElement('div');

  data.username.forEach((player) => {
    const playerSpan = document.createElement('span');
    playerSpan.innerText = `${player} `;
    playerContainer.appendChild(playerSpan);
  });

  const waitingForPlayersButton = document.createElement('a');
  waitingForPlayersButton.innerText = 'Waiting for players';
  waitingForPlayersButton.classList.add('button');
  waitingForPlayersButton.classList.add('gray');

  const gameContainer = document.querySelector('#current-game');
  gameContainer.innerText = '';
  gameContainer.appendChild(statusContainer);
  gameContainer.appendChild(playerContainer);
  gameContainer.appendChild(waitingForPlayersButton);
}
/**
 * Делает HTMLElement карту с соответсвующими id цветом и ранком
 */
function makeCardElement(id, color, rank) {
  const card = document.createElement('div');
  card.classList.add('card');
  card.classList.add(`card-${color}`);
  card.setAttribute('data-id', `${id}`);

  const cardInput = document.createElement('input');
  cardInput.type = 'checkbox';
  cardInput.id = `card-${id}`;
  cardInput.classList.add('card__input');

  const cardLabel = document.createElement('label');
  cardLabel.setAttribute('for', `card-${id}`);
  cardLabel.classList.add('card__label');
  if (rank === 13) cardLabel.innerText = '★';
  if (rank === 14) cardLabel.innerText = 'Skip';
  if (rank === 15) cardLabel.innerText = 'Deck';
  if (rank < 13) cardLabel.innerText = rank;

  card.appendChild(cardInput);
  card.appendChild(cardLabel);
  return card;
}
let chosenCards = [];

// eslint-disable-next-line no-param-reassign, no-bitwise
const hashCode = (s) => s.split('').reduce((a, b) => { a = ((a << 5) - a) + b.charCodeAt(0); return a & a; }, 0); // https://stackoverflow.com/a/15710692

let datahash = null; // чтобы автообновление ничего не сбрасывало
function createGameView(data) {
  // console.log(datahash);
  if (datahash === hashCode(JSON.stringify(data))) { //
    return; //
  }
  chosenCards = [];
  datahash = hashCode(JSON.stringify(data));
  document.querySelector('#enter').classList.add('hidden');
  document.querySelector('.gamecreateqq').classList.add('hidden');

  const statusContainer = document.createElement('div');
  const gameInfoSpan = document.createElement('span');
  gameInfoSpan.innerText = `Game #${data.my_cards[data.my_cards.length - 1]}`;
  const leaveButton = document.createElement('a');
  leaveButton.innerText = 'Leave';
  leaveButton.addEventListener('click', () => { leaveGame(); });
  leaveButton.classList.add('update');

  statusContainer.appendChild(gameInfoSpan);
  statusContainer.appendChild(leaveButton);

  const hand = document.createElement('div');
  hand.classList.add('hand');

  let index = 0;
  while (data.info[index] === 'hand') {
    const currentCard = makeCardElement(data.my_cards[index],
      data.color[index],
      data.rank[index]);
    // eslint-disable-next-line no-loop-func
    currentCard.children[0].addEventListener('click', (event) => {
      console.log(event.currentTarget.parentElement.getAttribute('data-id'));
      if (!chosenCards.includes(event.currentTarget.parentElement.getAttribute('data-id'))) {
        chosenCards.push(event.currentTarget.parentElement.getAttribute('data-id'));
      } else {
        chosenCards = chosenCards.filter((element) => element !== (event.currentTarget.parentElement.getAttribute('data-id')));
      }
      console.log(chosenCards);
    });
    hand.appendChild(currentCard);
    index += 1;
  }
  const fullTable = document.createElement('div');
  fullTable.classList.add('fulltable');
  const table = document.createElement('div');
  table.classList.add('table');
  table.appendChild(makeCardElement(-2,
    data.color[index],
    data.rank[index]));
  const deck = document.createElement('div');
  deck.classList.add('table');
  deck.appendChild(makeCardElement(-1, 'blue', 15));
  fullTable.appendChild(table);
  fullTable.appendChild(deck);
  index += 1;

  const currentPlayer = data.my_cards[index];

  const playerAndPhaseContainer = document.createElement('div');

  const phaseHeading = document.createElement('h3');
  phaseHeading.innerText = 'Phase';
  const phaseContent = document.createElement('span');
  phaseContent.innerText = data.rank[index];

  const playerHeading = document.createElement('h3');
  playerHeading.innerText = 'Players';

  playerAndPhaseContainer.appendChild(phaseHeading);
  playerAndPhaseContainer.appendChild(phaseContent);
  playerAndPhaseContainer.appendChild(playerHeading);
  index += 1;
  while (data.info[index] === 'players in game') {
    const playerContent = document.createElement('div');
    if (data.my_cards[index] === currentPlayer) {
      playerContent.classList.add('current-player');
    }

    const playerName = document.createElement('span');
    playerName.classList.add('player-name');
    playerName.innerText = data.my_cards[index];

    const playerScore = document.createElement('span');
    playerScore.classList.add('player-score');
    playerScore.innerText = data.color[index];

    playerContent.appendChild(playerName);
    playerContent.appendChild(playerScore);
    playerAndPhaseContainer.appendChild(playerContent);
    index += 1;
  }

  const gameContainer = document.querySelector('#current-game');
  gameContainer.innerText = '';
  gameContainer.appendChild(statusContainer);
  gameContainer.appendChild(playerAndPhaseContainer);
  gameContainer.appendChild(fullTable);
  gameContainer.appendChild(hand);

  console.log(sessionStorage.getItem('login'), currentPlayer);
  // eslint-disable-next-line eqeqeq
  if (sessionStorage.getItem('login').toLowerCase() == currentPlayer) {
    const newTakeButton = document.createElement('a');
    newTakeButton.classList.add('button');
    newTakeButton.appendChild(document.createTextNode('Take'));
    newTakeButton.setAttribute('id', 'take_card');
    newTakeButton.addEventListener('click', takeCard);

    const newPlaceButton = document.createElement('a');
    newPlaceButton.classList.add('button');
    newPlaceButton.appendChild(document.createTextNode('Place'));
    newPlaceButton.setAttribute('id', 'place_card');
    newPlaceButton.addEventListener('click', placeCard);

    const newPhaseButton = document.createElement('a');
    newPhaseButton.classList.add('button');
    newPhaseButton.appendChild(document.createTextNode('Phase'));
    newPhaseButton.setAttribute('id', 'set_phase');
    newPhaseButton.addEventListener('click', () => { phase(data); });

    const allButtons = document.createElement('div');
    allButtons.classList.add('inGameButtons');

    allButtons.appendChild(newTakeButton);
    allButtons.appendChild(newPlaceButton);
    allButtons.appendChild(newPhaseButton);

    gameContainer.appendChild(allButtons);
  } else {
    const waitingForPlayersButton = document.createElement('a');
    waitingForPlayersButton.innerText = `${currentPlayer}'s turn`;
    waitingForPlayersButton.classList.add('button');
    waitingForPlayersButton.classList.add('gray');
    gameContainer.appendChild(waitingForPlayersButton);
  }
}

function phase(data) {
  console.log('currentPhase', data.rank[data.color.indexOf('phase')]);
  const currentPhase = data.rank[data.color.indexOf('phase')];
  console.log('really?', currentPhase);
  switch (currentPhase) {
    case 1:
      phase1();
      break;
    case 2:
      phase2();
      break;
    case 3:
      phase3();
      break;
    case 4:
      phase4();
      break;
    case 5:
      phase5();
      break;
    case 6:
      phase6();
      break;
    case 7:
      phase7();
      break;
    case 8:
      phase8();
      break;
    case 9:
      phase9();
      break;
    case 10:
      phase10();
      break;
    default:
  }
}

async function phase1() {
  const fd = new FormData();
  fd.set('db', '3396'); // указываем бд
  fd.set('pname', 'phase1'); // указываем процедуру из sql
  fd.set('p1', sessionStorage.getItem('login')); // указываем первый параметр, который передается в процедуру в sql
  fd.set('p2', sessionStorage.getItem('pw')); // указывает второй параметр
  fd.set('p3', chosenCards[0]);
  fd.set('p4', chosenCards[1]);
  fd.set('p5', chosenCards[2]);
  fd.set('p6', chosenCards[3]);
  fd.set('p7', chosenCards[4]);
  fd.set('p8', chosenCards[5]);
  try {
    const res = await (await postFormdata('https://play.lavro.ru/call.php', fd)) // ждем результата запроса
      .json(); // ждем json
    handler(res);
  } catch (e) {
    showError(e);
    console.error(e);
  }
}

async function phase2() {
  const fd = new FormData();
  fd.set('db', '3396'); // указываем бд
  fd.set('pname', 'phase2'); // указываем процедуру из sql
  fd.set('p1', sessionStorage.getItem('login')); // указываем первый параметр, который передается в процедуру в sql
  fd.set('p2', sessionStorage.getItem('pw')); // указывает второй параметр
  fd.set('p3', chosenCards[0]);
  fd.set('p4', chosenCards[1]);
  fd.set('p5', chosenCards[2]);
  fd.set('p6', chosenCards[3]);
  fd.set('p7', chosenCards[4]);
  try {
    const res = await (await postFormdata('https://play.lavro.ru/call.php', fd)) // ждем результата запроса
      .json(); // ждем json
    handler(res);
  } catch (e) {
    showError(e);
    console.error(e);
  }
}

async function phase3() {
  const fd = new FormData();
  fd.set('db', '3396'); // указываем бд
  fd.set('pname', 'phase3'); // указываем процедуру из sql
  fd.set('p1', sessionStorage.getItem('login')); // указываем первый параметр, который передается в процедуру в sql
  fd.set('p2', sessionStorage.getItem('pw')); // указывает второй параметр
  fd.set('p3', chosenCards[0]);
  fd.set('p4', chosenCards[1]);
  fd.set('p5', chosenCards[2]);
  fd.set('p6', chosenCards[3]);
  fd.set('p7', chosenCards[4]);
  try {
    const res = await (await postFormdata('https://play.lavro.ru/call.php', fd)) // ждем результата запроса
      .json(); // ждем json
    handler(res);
  } catch (e) {
    showError(e);
    console.error(e);
  }
}

async function phase4() {
  const fd = new FormData();
  fd.set('db', '3396'); // указываем бд
  fd.set('pname', 'phase4'); // указываем процедуру из sql
  fd.set('p1', sessionStorage.getItem('login')); // указываем первый параметр, который передается в процедуру в sql
  fd.set('p2', sessionStorage.getItem('pw')); // указывает второй параметр
  fd.set('p3', chosenCards[0]);
  fd.set('p4', chosenCards[1]);
  fd.set('p5', chosenCards[2]);
  fd.set('p6', chosenCards[3]);
  fd.set('p7', chosenCards[4]);
  fd.set('p8', chosenCards[5]);
  fd.set('p9', chosenCards[6]);
  try {
    const res = await (await postFormdata('https://play.lavro.ru/call.php', fd)) // ждем результата запроса
      .json(); // ждем json
    handler(res);
  } catch (e) {
    showError(e);
    console.error(e);
  }
}

async function phase5() {
  const fd = new FormData();
  fd.set('db', '3396'); // указываем бд
  fd.set('pname', 'phase5'); // указываем процедуру из sql
  fd.set('p1', sessionStorage.getItem('login')); // указываем первый параметр, который передается в процедуру в sql
  fd.set('p2', sessionStorage.getItem('pw')); // указывает второй параметр
  fd.set('p3', chosenCards[0]);
  fd.set('p4', chosenCards[1]);
  fd.set('p5', chosenCards[2]);
  fd.set('p6', chosenCards[3]);
  fd.set('p7', chosenCards[4]);
  fd.set('p8', chosenCards[5]);
  fd.set('p9', chosenCards[6]);
  fd.set('p10', chosenCards[7]);
  try {
    const res = await (await postFormdata('https://play.lavro.ru/call.php', fd)) // ждем результата запроса
      .json(); // ждем json
    handler(res);
  } catch (e) {
    showError(e);
    console.error(e);
  }
}

async function phase6() {
  const fd = new FormData();
  fd.set('db', '3396'); // указываем бд
  fd.set('pname', 'phase6'); // указываем процедуру из sql
  fd.set('p1', sessionStorage.getItem('login')); // указываем первый параметр, который передается в процедуру в sql
  fd.set('p2', sessionStorage.getItem('pw')); // указывает второй параметр
  fd.set('p3', chosenCards[0]);
  fd.set('p4', chosenCards[1]);
  fd.set('p5', chosenCards[2]);
  fd.set('p6', chosenCards[3]);
  fd.set('p7', chosenCards[4]);
  fd.set('p8', chosenCards[5]);
  fd.set('p9', chosenCards[6]);
  fd.set('p10', chosenCards[7]);
  try {
    const res = await (await postFormdata('https://play.lavro.ru/call.php', fd)) // ждем результата запроса
      .json(); // ждем json
    handler(res);
  } catch (e) {
    showError(e);
    console.error(e);
  }
}

async function phase7() {
  const fd = new FormData();
  fd.set('db', '3396'); // указываем бд
  fd.set('pname', 'phase7'); // указываем процедуру из sql
  fd.set('p1', sessionStorage.getItem('login')); // указываем первый параметр, который передается в процедуру в sql
  fd.set('p2', sessionStorage.getItem('pw')); // указывает второй параметр
  fd.set('p3', chosenCards[0]);
  fd.set('p4', chosenCards[1]);
  fd.set('p5', chosenCards[2]);
  fd.set('p6', chosenCards[3]);
  fd.set('p7', chosenCards[4]);
  fd.set('p8', chosenCards[5]);
  fd.set('p9', chosenCards[6]);
  fd.set('p10', chosenCards[7]);
  fd.set('p11', chosenCards[8]);
  try {
    const res = await (await postFormdata('https://play.lavro.ru/call.php', fd)) // ждем результата запроса
      .json(); // ждем json
    handler(res);
  } catch (e) {
    showError(e);
    console.error(e);
  }
}

async function phase8() {
  const fd = new FormData();
  fd.set('db', '3396'); // указываем бд
  fd.set('pname', 'phase8'); // указываем процедуру из sql
  fd.set('p1', sessionStorage.getItem('login')); // указываем первый параметр, который передается в процедуру в sql
  fd.set('p2', sessionStorage.getItem('pw')); // указывает второй параметр
  fd.set('p3', chosenCards[0]);
  fd.set('p4', chosenCards[1]);
  fd.set('p5', chosenCards[2]);
  fd.set('p6', chosenCards[3]);
  fd.set('p7', chosenCards[4]);
  fd.set('p8', chosenCards[5]);
  fd.set('p9', chosenCards[6]);
  try {
    const res = await (await postFormdata('https://play.lavro.ru/call.php', fd)) // ждем результата запроса
      .json(); // ждем json
    handler(res);
  } catch (e) {
    showError(e);
    console.error(e);
  }
}

async function phase9() {
  const fd = new FormData();
  fd.set('db', '3396'); // указываем бд
  fd.set('pname', 'phase9'); // указываем процедуру из sql
  fd.set('p1', sessionStorage.getItem('login')); // указываем первый параметр, который передается в процедуру в sql
  fd.set('p2', sessionStorage.getItem('pw')); // указывает второй параметр
  fd.set('p3', chosenCards[0]);
  fd.set('p4', chosenCards[1]);
  fd.set('p5', chosenCards[2]);
  fd.set('p6', chosenCards[3]);
  fd.set('p7', chosenCards[4]);
  fd.set('p8', chosenCards[5]);
  fd.set('p9', chosenCards[6]);
  fd.set('p10', chosenCards[7]);
  fd.set('p11', chosenCards[8]);
  try {
    const res = await (await postFormdata('https://play.lavro.ru/call.php', fd)) // ждем результата запроса
      .json(); // ждем json
    handler(res);
  } catch (e) {
    showError(e);
    console.error(e);
  }
}

async function phase10() {
  const fd = new FormData();
  fd.set('db', '3396'); // указываем бд
  fd.set('pname', 'phase10'); // указываем процедуру из sql
  fd.set('p1', sessionStorage.getItem('login')); // указываем первый параметр, который передается в процедуру в sql
  fd.set('p2', sessionStorage.getItem('pw')); // указывает второй параметр
  fd.set('p3', chosenCards[0]);
  fd.set('p4', chosenCards[1]);
  fd.set('p5', chosenCards[2]);
  fd.set('p6', chosenCards[3]);
  fd.set('p7', chosenCards[4]);
  fd.set('p8', chosenCards[5]);
  fd.set('p9', chosenCards[6]);
  fd.set('p10', chosenCards[7]);
  try {
    const res = await (await postFormdata('https://play.lavro.ru/call.php', fd)) // ждем результата запроса
      .json(); // ждем json
    handler(res);
  } catch (e) {
    showError(e);
    console.error(e);
  }
}

async function getGameState() {
  const fd = new FormData();
  fd.set('db', '3396'); // указываем бд
  fd.set('pname', 'game_state'); // указываем процедуру из sql
  fd.set('p1', sessionStorage.getItem('login')); // указываем первый параметр, который передается в процедуру в sql
  fd.set('p2', sessionStorage.getItem('pw')); // указывает второй параметр
  try {
    const res = await (await postFormdata('https://play.lavro.ru/call.php', fd)) // ждем результата запроса
      .json(); // ждем json
    handler(res);
  } catch (e) {
    showError(e);
    console.error(e);
  }
}

async function takeCard() {
  const fd = new FormData();
  fd.set('db', '3396'); // указываем бд
  fd.set('pname', 't_card'); // указываем процедуру из sql
  fd.set('p1', sessionStorage.getItem('login')); // указываем первый параметр, который передается в процедуру в sql
  fd.set('p2', sessionStorage.getItem('pw')); // указывает второй параметр
  if ((document.querySelector('#card--1').checked)
      && (document.querySelector('#card--2').checked)) {
    console.log('hey, what are u doing?');
    return;
  }
  if ((document.querySelector('#card--1').checked)
      && !(document.querySelector('#card--2').checked)) {
    fd.set('p3', 1); // указывает второй параметр
  }
  if (!(document.querySelector('#card--1').checked)
      && (document.querySelector('#card--2').checked)) {
    fd.set('p3', 2); // взяли со стола
    // document.querySelector('#card--2').classList.add('fulltable');
  }

  try {
    const res = await (await postFormdata('https://play.lavro.ru/call.php', fd)) // ждем результата запроса
      .json(); // ждем json
    handler(res);
  } catch (e) {
    showError(e);
    console.error(e);
  }
}

async function placeCard() {
  const fd = new FormData();
  fd.set('db', '3396'); // указываем бд
  fd.set('pname', 'p_card'); // указываем процедуру из sql
  fd.set('p1', sessionStorage.getItem('login')); // указываем первый параметр, который передается в процедуру в sql
  fd.set('p2', sessionStorage.getItem('pw')); // указывает второй параметр
  if ((chosenCards.length) === 1) {
    fd.set('p3', chosenCards[0]); // указывает второй параметр
  } else {
    console.log('select one card only');
  }

  try {
    const res = await (await postFormdata('https://play.lavro.ru/call.php', fd)) // ждем результата запроса
      .json(); // ждем json
    handler(res);
  } catch (e) {
    showError(e);
    console.error(e);
  }
}

/**
 * При клике на игру в списке
 * @param {MouseEvent} event
 */
async function gameClickHandler(event) {
  console.log(`clicked on ${event.currentTarget.getAttribute('data-game-id')}`);

  const fd = new FormData();
  fd.set('db', '3396'); // указываем бд
  fd.set('pname', 'game_connect'); // указываем процедуру из sql
  fd.set('p1', sessionStorage.getItem('login')); // указываем первый параметр, который передается в процедуру в sql
  fd.set('p2', sessionStorage.getItem('pw')); // указывает второй параметр
  fd.set('p3', event.currentTarget.getAttribute('data-game-id')); // количество игроков
  try {
    const res = await (await postFormdata('https://play.lavro.ru/call.php', fd)) // ждем результата запроса
      .json(); // ждем json
    document.querySelector('#cont').classList.add('hidden');
    handler(res);
  } catch (e) {
    // showError(e);
    console.error(e);
  }
}

function listHandler(data) {
  const ent = document.querySelector('#enter');
  ent.classList.add('hidden');

  document.querySelector('#cont').innerHTML = '<span>List of games</span>';
  const updateSpan = document.createElement('a');
  updateSpan.innerText = 'Update';
  updateSpan.classList.add('update');
  updateSpan.addEventListener('click', () => { login(); });
  document.querySelector('#cont').appendChild(updateSpan);
  const gameList = document.createElement('div');
  // if (!(Object.keys(data).includes('Empty'))) {
  console.log('game id count: ', data.game_id.length);
  for (let i = 0; i < data.game_id.length; i += 1) {
    const newContainer = document.createElement('div');
    const newHeading = document.createElement('h3');
    newHeading.appendChild(document.createTextNode(`Game #${data.game_id[i]}`));
    const newSpan = document.createElement('span');
    newSpan.appendChild(document.createTextNode(`Created by ${data.created_by[i]}`));
    newContainer.appendChild(newHeading);
    newContainer.appendChild(newSpan);
    newContainer.setAttribute('data-game-id', data.game_id[i]);
    newContainer.addEventListener('click', gameClickHandler);
    gameList.appendChild(newContainer);
  }
  // }

  document.querySelector('#cont').appendChild(gameList);
  const newButton = document.createElement('a');
  newButton.classList.add('button');
  newButton.appendChild(document.createTextNode('Create game'));
  newButton.setAttribute('id', 'create_game');
  newButton.addEventListener('click', createGame);
  document.querySelector('#cont').appendChild(newButton);

  // document.querySelector('#cont').appendChild(makeCardElement(1234, 'blue', 2));
  // document.querySelector('#cont').appendChild(makeCardElement(1434, 'red', 1));
  // document.querySelector('#cont').appendChild(makeCardElement(5131, 'yellow', 10));
}

function endedGameState(data) {
  document.querySelector('#enter').classList.add('hidden');
  document.querySelector('.gamecreateqq').classList.add('hidden');

  const statusContainer = document.createElement('div');
  const gameInfoSpan = document.createElement('span');
  let index = 0;
  gameInfoSpan.innerText = 'Game is over';
  const leaveButton = document.createElement('a');
  leaveButton.innerText = 'Leave';
  leaveButton.addEventListener('click', () => { leaveGame(); });
  leaveButton.classList.add('update');

  statusContainer.appendChild(gameInfoSpan);
  statusContainer.appendChild(leaveButton);

  const playerAndPhaseContainer = document.createElement('div');

  while (index < data.info.length) {
    const playerContent = document.createElement('div');

    const playerName = document.createElement('span');
    playerName.classList.add('player-name');
    playerName.innerText = data.players[index];

    const playerScore = document.createElement('span');
    playerScore.classList.add('player-score');
    playerScore.innerText = data.Points[index];

    playerContent.appendChild(playerName);
    playerContent.appendChild(playerScore);
    playerAndPhaseContainer.appendChild(playerContent);
    index += 1;
  }

  const gameContainer = document.querySelector('#current-game');
  gameContainer.innerText = '';
  gameContainer.appendChild(statusContainer);
  gameContainer.appendChild(playerAndPhaseContainer);

  const waitingForPlayersButton = document.createElement('a');
  waitingForPlayersButton.innerText = 'Leave game';
  waitingForPlayersButton.classList.add('button');
  waitingForPlayersButton.addEventListener('click', () => { leaveGame(); });
  gameContainer.appendChild(waitingForPlayersButton);
}

function emptyListHandler(data) {
  const ent = document.querySelector('#enter');
  ent.classList.add('hidden');

  document.querySelector('#cont').innerHTML = '<span>List of games is empty</span>';
  const updateSpan = document.createElement('a');
  updateSpan.innerText = 'Update';
  updateSpan.classList.add('update');
  updateSpan.addEventListener('click', () => { login(); });
  document.querySelector('#cont').appendChild(updateSpan);
  console.log('game id count: ', data.Empty);
  console.log('now button');
  const newButton = document.createElement('a');
  newButton.classList.add('button');
  newButton.appendChild(document.createTextNode('Create game'));
  newButton.setAttribute('id', 'create_game');
  newButton.addEventListener('click', createGame);
  document.querySelector('#cont').appendChild(newButton);
  console.log('button?');
}

let stateTimeout = null;
function handler(data) {
  if (Object.keys(data).includes('Account created!')) { // создание аккаунта
    login();
    return;
  }
  if (Object.keys(data).length === 2
      && Object.keys(data).includes('Empty')
      && Object.keys(data).includes('Create your own game')) { // пустой список игр
    emptyListHandler(data);
    console.log('Empty list');
    return;
  }
  if (Object.keys(data).length === 3
      && Object.keys(data).includes('game_id')
      && Object.keys(data).includes('created_by')
      && Object.keys(data).includes('minutes_ago')) { // не пустой список игр
    listHandler(data);
    return;
  }

  if (Object.keys(data).length === 3
    && Object.keys(data).includes('info')
    && Object.keys(data).includes('players')
    && Object.keys(data).includes('Points')) { // мы в игре, получаем стейт
    endedGameState(data);
    return;
  }

  if (Object.keys(data).length === 1
      && Object.keys(data).includes('players_in_game')) { // game_connect если еще ждем -> вызываем game_state
    getGameState();
    return;
  }
  if (Object.keys(data).length === 2
    && Object.keys(data).includes('You are in game already')
    && Object.keys(data).includes('game_id')) { // мы в игре, получаем стейт
    getGameState();
    clearTimeout(stateTimeout);
    stateTimeout = setTimeout(getGameState, 5000);
    console.log(`Все тебя ждут в игре №${data.game_id[0]}`);
    return;
  }
  if (Object.keys(data).length === 2
    && Object.keys(data).includes('waiting_for_players')
    && Object.keys(data).includes('username')) { // стейт игры == ждем игроков
    createWaitingForGameView(data);
    clearTimeout(stateTimeout);
    stateTimeout = setTimeout(getGameState, 5000);
    const gameCreate = document.querySelector('.gamecreateqq');
    gameCreate.classList.add('hidden');
    // eslint-disable-next-line max-len
    // console.log(`мы ждем в игре ${data.waiting_for_players[0]}, с нами ${data.username.toString()}`);
    return;
  }
  if (Object.keys(data).length === 4
    && Object.keys(data).includes('info')
    && Object.keys(data).includes('my_cards')
    && Object.keys(data).includes('color')
    && Object.keys(data).includes('rank')) { // стейт игры == Играем
    const gameCreate = document.querySelector('.gamecreateqq');
    gameCreate.classList.add('hidden');
    createGameView(data);
    clearTimeout(stateTimeout);
    stateTimeout = setTimeout(getGameState, 5000);
    return;
  }
  if (Object.keys(data).length === 2
    && Object.keys(data).includes('Yay')
    && Object.keys(data).includes('Game start!')) { // стейт игры == Играем
    const gameCreate = document.querySelector('.gamecreateqq');
    gameCreate.classList.add('hidden');
    createGameView(data);
    clearTimeout(stateTimeout);
    stateTimeout = setTimeout(getGameState, 5000);
    return;
  }

  statusHandler(data);
}

async function register() {
  const loginInput = document.querySelector('#login');
  const passwordInput = document.querySelector('#pw');

  sessionStorage.setItem('login', loginInput.value.toLowerCase());
  sessionStorage.setItem('pw', passwordInput.value);

  const fd = new FormData();
  fd.set('db', '3396'); // указываем бд
  fd.set('pname', 'sign_up'); // указываем процедуру из sql
  fd.set('p1', loginInput.value); // указываем первый параметр, который передается в процедуру в sql
  fd.set('p2', passwordInput.value); // указывает второй параметр
  // fd.set("format", "string"); //это, чтобы удобнее было работать с тем, что вернет sql

  try {
    const res = await (await postFormdata('https://play.lavro.ru/call.php', fd)) // ждем результата запроса
      .json(); // ждем json
    handler(res);
  } catch (e) {
    showError(e);
    console.error(e);
  }
}

async function login() {
  let loginInput = sessionStorage.getItem('login');
  let passwordInput = sessionStorage.getItem('pw');
  if (typeof loginInput === 'undefined' || loginInput === null) {
    loginInput = document.querySelector('#loginl').value;
    passwordInput = document.querySelector('#pwl').value;

    sessionStorage.setItem('login', loginInput);
    sessionStorage.setItem('pw', passwordInput);
  }

  const fd = new FormData();
  fd.set('db', '3396'); // указываем бд
  fd.set('pname', 'list_of_games'); // указываем процедуру из sql
  fd.set('p1', loginInput); // указываем первый параметр, который передается в процедуру в sql
  fd.set('p2', passwordInput); // указывает второй параметр
  // fd.set('format', 'columns'); //это, чтобы удобнее было работать с тем, что вернет sql

  try {
    const res = await (await postFormdata('https://play.lavro.ru/call.php', fd)) // ждем результата запроса
      .json(); // ждем json

    // const lg = document.getElementsByClassName('regqq');
    // lg[0].classList.toggle('hidden');
    console.log('kk', res);
    handler(res);
  } catch (e) {
    showError(e);
    console.error(e);
  }
}

async function createGame() {
  const players = document.querySelector('.plnum').elements.radio.value;
  const fd = new FormData();
  fd.set('db', '3396'); // указываем бд
  fd.set('pname', 'create_game'); // указываем процедуру из sql
  fd.set('p1', sessionStorage.getItem('login')); // указываем первый параметр, который передается в процедуру в sql
  fd.set('p2', sessionStorage.getItem('pw')); // указывает второй параметр
  fd.set('p3', 2); // количество игроков
  try {
    const res = await (await postFormdata('https://play.lavro.ru/call.php', fd)) // ждем результата запроса
      .json(); // ждем json
  const gc = document.querySelector('.gamecreateqq');
  const ent = document.querySelector('#cont');
  ent.classList.toggle('hidden');
  gc.classList.toggle('hidden');
    handler(res);
  } catch (e) {
    showError(e);
    console.error(e);
  }
}

document.querySelector('#login_button').addEventListener('click', () => { login(); });
document.querySelector('#register_button').addEventListener('click', () => { register(); });

document.querySelector('#create_game_button').addEventListener('click', () => { createGame(); });

const menuSwitchers = document.querySelectorAll('#menu_switcher');
menuSwitchers.forEach((switcher) => switcher.addEventListener('click', () => { switchMenus(); }));
