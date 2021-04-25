use host700505_3396;

-- ### Таблицы

-- создание
CREATE TABLE Users(username VARCHAR(30) not NULL PRIMARY KEY, 
				   u_password VARCHAR(30) not null,
				   activity TIMESTAMP not null,
				   p_count INT not NULL);

CREATE TABLE Players(username VARCHAR(30) not NULL PRIMARY KEY, 
					 points INT not NULL, 
					 next_player VARCHAR(30), 
					 game_id int NOT null, 
					 FOREIGN KEY(username) REFERENCES Users(username),
					 FOREIGN KEY(next_player) REFERENCES Players(username),
					 FOREIGN KEY(game_id) REFERENCES Games(game_id);

CREATE TABLE Card_type(id INT not NULL PRIMARY KEY,
					   color VARCHAR(10) not NULL, 
					   rank INT not NULL);

CREATE TABLE Cards(card_id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
                   id INT not NULL, 
                   FOREIGN KEY (id) REFERENCES Card_type(id));

CREATE TABLE Turns(current_player VARCHAR(30) not NULL PRIMARY KEY, 
				   FOREIGN KEY (current_player) REFERENCES Players(username));

CREATE TABLE Cards_in_hand(card_id INT not NULL PRIMARY KEY, 
                           username VARCHAR(30) not NULL, 
                           FOREIGN KEY (card_id) REFERENCES Cards(card_id),
                           FOREIGN KEY (username) REFERENCES Users(username));

CREATE TABLE Games (game_id INT not NULL PRIMARY KEY AUTO_INCREMENT, 
                    card_on_table INT, 
                    game_phase INT not NULL, 
                    FOREIGN KEY (card_on_table) REFERENCES Cards(card_id));

CREATE TABLE Decks (card_id INT not NULL PRIMARY KEY, 
                    game_id INT not NULL, 
                    FOREIGN KEY (card_id) REFERENCES Cards(card_id),
                    FOREIGN KEY (game_id) REFERENCES Games(game_id));

-- ### Процедуры

-- регистрация нового пользователя
DELIMITER //

CREATE PROCEDURE sign_up(login VARCHAR(30), pw VARCHAR(20))
BEGIN
	IF ((SELECT COUNT(*) from Users WHERE username=login) != 0) THEN
    	SELECT "Error", "Same login already exists";
    ELSEIF Length(login) < 2 THEN
    	SELECT "Error", "Login is too short";
    ELSEIF Length(pw) < 2 THEN
    	SELECT "Error", "Password is too short";
    ELSE 
    	INSERT INTO Users VALUES(login, pw, CURRENT_TIMESTAMP, 2);
        SELECT "Account created!";
    END IF;
END //

-- создание игры
DELIMITER //

CREATE PROCEDURE create_game(login VARCHAR(30), pw VARCHAR(20), pl_count INT)
BEGIN
    IF (pl_count < 2 OR pl_count > 6) THEN 
        SELECT "Error", "Wrong number of players";
    ELSEIF ((SELECT COUNT(*) from Users WHERE username=login and u_password=pw) = 1) THEN
            UPDATE Users SET activity = CURRENT_TIMESTAMP WHERE username=login and u_password=pw;
            UPDATE Users SET p_count = pl_count WHERE username=login and u_password=pw;
            INSERT INTO Games VALUES(NULL, NULL, 1);
            INSERT INTO Players VALUES(login, 0, NULL, (SELECT game_id FROM Games order by game_id DESC LIMIT 1));
            INSERT INTO Cards (id) SELECT id FROM Card_type LIMIT 108; -- создаем колоду
            INSERT INTO Decks(card_id, game_id) SELECT card_id, game_id FROM Cards, Games WHERE game_id=(SELECT game_id FROM Games order by game_id DESC LIMIT 1) order by card_id desc LIMIT 108; -- создаем колоду
            INSERT INTO Turns VALUES(login); -- присваиваем текущего игрока
            INSERT INTO Cards_in_hand (card_id, username) SELECT card_id, current_player FROM Turns, Decks where current_player=login and game_id=(SELECT game_id FROM Games order by game_id DESC LIMIT 1) order by RAND() limit 10; -- даем на руку
            SELECT username as players_in_game FROM Players WHERE game_id = (SELECT game_id FROM Games order by game_id DESC LIMIT 1);
            -- SELECT "Waiting for players";
    ELSE SELECT "Error", "wrong login or password";
    END IF;

END//

-- список игр
DELIMITER //

CREATE PROCEDURE list_of_games(login VARCHAR(30), pw VARCHAR(20))
BEGIN
    
    IF ((SELECT COUNT(*) from Users WHERE username=login and u_password=pw) = 0) THEN
        SELECT "Error", "Wrong password";
    ELSEIF ((SELECT COUNT(*) FROM Players WHERE username=login) = 1) THEN
        SELECT "You are in game already", (SELECT game_id FROM Players WHERE username=login) as game_id;
    ELSE
        IF ((SELECT Count(*) FROM Users natural JOIN Players NATURAL join Games where card_on_table is NULL and TIMEDIFF(CURRENT_TIMESTAMP, activity) <= 60000) = 0) THEN
            SELECT "Empty", "Create your own game";
        ELSE    
            SELECT game_id, username as created_by, TIMESTAMPDIFF(MINUTE, activity, CURRENT_TIMESTAMP) as minutes_ago 
            FROM Users natural JOIN Players 
                       NATURAL join Games 
            where next_player is null and TIMEDIFF(CURRENT_TIMESTAMP, activity) <= 60000
            order by activity ASC; 
        END IF;
    END IF;

END//
-- test
call list_of_games ('testerguy', '123')


-- подключение к игре
DELIMITER //

CREATE PROCEDURE game_connect(login VARCHAR(30), pw VARCHAR(20), game_id_to_connect INT)
BEGIN
    DECLARE cur_p VARCHAR(30);
    DECLARE cnt_p INT;
    IF ((SELECT COUNT(*) from Users WHERE username=login and u_password=pw) = 1) THEN
        IF ((SELECT COUNT(*) FROM Games WHERE game_id=game_id_to_connect) = 1) THEN
            UPDATE Users SET activity = CURRENT_TIMESTAMP WHERE username=login and u_password=pw;             
            SET cnt_p = (SELECT p_count FROM Players natural join Users where game_id=game_id_to_connect and next_player is NULL);             
            UPDATE Users SET p_count = cnt_p WHERE username=login and u_password=pw;             
            SET cur_p = (SELECT current_player FROM Players, Turns where username=current_player and game_id=game_id_to_connect);             
            INSERT INTO Players VALUES(login, 0, cur_p, game_id_to_connect);             
            INSERT INTO Cards_in_hand (card_id, username) SELECT distinct Decks.card_id, login FROM Decks, Cards_in_hand where game_id=game_id_to_connect and Decks.card_id  NOT IN(SELECT card_id FROM Cards_in_hand where game_id=game_id_to_connect)  order by RAND() limit 10;
            IF ((SELECT COUNT(*) FROM Players WHERE game_id=game_id_to_connect) < cnt_p) THEN                 
                UPDATE Turns SET current_player = login WHERE current_player=cur_p;              
                ELSE                 
                UPDATE Games SET card_on_table = (SELECT distinct Decks.card_id FROM Decks, Cards_in_hand where game_id=game_id_to_connect and Decks.card_id  NOT IN(SELECT card_id FROM Cards_in_hand where game_id=game_id_to_connect)  order by RAND() limit 1) WHERE (game_id=game_id_to_connect);
                UPDATE Players SET next_player = login WHERE game_id = game_id_to_connect and next_player is NULL; 
                IF (cur_p != (SELECT username FROM Players WHERE game_id = game_id_to_connect and next_player is NULL)) THEN
                    UPDATE Turns SET current_player = (SELECT username FROM Players WHERE game_id = game_id_to_connect ORDER BY Rand() LIMIT 1); 
                END IF;
                SELECT "Yay", "Game start!";
            END IF;
            SELECT username as players_in_game FROM Players WHERE game_id = game_id_to_connect;
        ELSE 
            SELECT "Error", "Wrong game_id, check list of games";
            
        END IF;
    ELSE 
        SELECT "Error", "Wrong password";
    END IF;

END//


--game_state
DELIMITER //

CREATE PROCEDURE game_state(login VARCHAR(30), pw VARCHAR(20))
BEGIN
    IF ((SELECT COUNT(*) from Users WHERE username=login and u_password=pw) = 0) THEN
        SELECT "Error", "Wrong password";
    ELSEIF ((SELECT COUNT(*) FROM Players WHERE username=login) = 0) THEN
        SELECT "Error", "Connect to game or create new first";
    ELSEIF ((SELECT COUNT(card_on_table) FROM Games WHERE game_id=(select game_id from Players where username=login)) = 0) THEN
        SELECT "Waiting for players", 
        (SELECT COUNT(username) as players_in_game FROM Players WHERE game_id=(select game_id from Players where username=login)) as players_in_game;
    ELSE 
        IF ((SELECT game_phase FROM Games WHERE game_id=(SELECT game_id FROM Players WHERE username=login))=11) THEN
            SELECT 'Game is over' as info, username as players, points as Points FROM Players WHERE game_id=(SELECT game_id FROM Players WHERE username=login ORDER by points asc);
        END IF;  
        SELECT 'hand' as info, card_id as my_cards, color, rank FROM Cards_in_hand natural join Cards natural join Card_type WHERE username=login
        UNION SELECT 'table', card_on_table, color, rank FROM Games natural join Cards natural join Card_type where game_id=(select game_id from Players where username=login) and Cards.card_id = card_on_table  union SELECT 'current player', current_player, 'plase', (SELECT game_phase FROM Games WHERE game_id=(select game_id from Players where username=login)) FROM Turns, Players WHERE game_id=(select game_id from Players where username=login) and current_player=username UNION SELECT 'players in game', username, points, next_player FROM Players, Turns WHERE game_id=(select game_id from Players where username=login);
        END IF;
END//

--leave_game
DELIMITER //

CREATE PROCEDURE leave_game(login VARCHAR(30), pw VARCHAR(20))
BEGIN
    DECLARE n_p VARCHAR(30);
    DECLARE g_i INT;
    CREATE TEMPORARY TABLE ctd(c_i INT);
    IF ((SELECT COUNT(*) from Users WHERE username=login and u_password=pw) = 0) THEN
        SELECT "Error", "Wrong password";
    ELSEIF ((SELECT COUNT(*) FROM Players WHERE username=login) = 0) THEN
        SELECT "Error", "You are not in game now";
    ELSE  
        IF ((SELECT next_player FROM Players WHERE username=login)= login) or ((SELECT count(*) FROM Players WHERE username=login and next_player is NULL)=1) THEN         
            DELETE FROM Cards_in_hand WHERE username=login;
            DELETE FROM Turns WHERE current_player=login;
            UPDATE Players SET next_player = null WHERE username=login;
            set g_i = (SELECT game_id FROM Players WHERE username=login);
            DELETE FROM Players WHERE username=login;
            UPDATE Games SET card_on_table = null WHERE game_id=g_i;
            INSERT INTO ctd(c_i) SELECT card_id FROM Decks WHERE game_id=g_i;
            DELETE FROM Decks WHERE game_id = g_i;
            DELETE FROM Cards WHERE card_id IN (SELECT c_i FROM ctd);
            DELETE FROM Games WHERE game_id = g_i;
            UPDATE Users SET p_count=2 WHERE username=login;
            SELECT "now you can find new game";
        end if;
        
        
        IF (((SELECT COUNT(*) from Cards_in_hand WHERE username=login) != 10) and ((SELECT game_phase FROM Games WHERE game_id=(SELECT game_id FROM Players WHERE username=login))!=11)) THEN           SELECT "Error", "End your turn first";
        ELSE
            DELETE FROM Cards_in_hand WHERE username=login;
            IF ((SELECT COUNT(*) from Turns WHERE current_player=login) = 1) THEN               UPDATE Turns SET current_player = (SELECT next_player FROM Players WHERE username=login);
            END IF;
            set n_p = (SELECT next_player FROM Players WHERE username=login);
            UPDATE Players SET next_player = null WHERE username=login;
            UPDATE Players SET next_player = n_p WHERE next_player=login;
            DELETE FROM Players WHERE username=login;
            UPDATE Users SET p_count=2 WHERE username=login;
        END IF;
        SELECT "now you can find new game";
        
    END IF;

END//


--t_card: take card

DELIMITER //

CREATE PROCEDURE t_card(login VARCHAR(30), pw VARCHAR(20), c ENUM('deck','table'))
BEGIN
    DECLARE c_g INT;
    SET c_g=(select game_id from Players where username=login);
    IF ((SELECT COUNT(*) from Users WHERE username=login and u_password=pw) = 0) THEN
        SELECT "Error", "Wrong password";
    ELSEIF ((SELECT COUNT(*) FROM Players WHERE username=login) = 0) THEN
        SELECT "Error", "Connect to game or create new first";
    ELSEIF ((SELECT COUNT(card_on_table) FROM Games WHERE game_id=c_g) = 0) THEN
        SELECT "Error","Waiting for players", 
        (SELECT COUNT(username) as players_in_game FROM Players WHERE game_id=c_g) as players_in_game;
    ELSEIF ((SELECT current_player FROM Turns, Players WHERE game_id=c_g and current_player=username) != login) THEN
        SELECT "Error", (SELECT current_player FROM Turns, Players WHERE game_id=c_g and current_player=username) as current_player, (SELECT card_on_table FROM Games WHERE game_id=c_g) as card_on_table;
    ELSE -- добрались до игры
        IF ((SELECT COUNT(card_id) FROM Cards_in_hand WHERE username=login) = 11) THEN -- уже брал
                    SELECT "You can't take more cards", "Call p_card to finish your turn";
        end IF;
        IF (c='deck') THEN
            IF ((SELECT COUNT(card_id) FROM Cards_in_hand WHERE username=login) = 10 ) THEN -- можно взять из колоды
                    INSERT INTO Cards_in_hand (card_id, username) SELECT card_id, login FROM Decks where game_id=c_g and card_id  NOT IN (SELECT card_id FROM Cards_in_hand where game_id=c_g) and card_id!=(select card_on_table from Games where game_id=c_g) order by RAND() limit 1; -- добавить карту в руку из колоды
            ELSEIF ((SELECT COUNT(card_id) FROM Cards_in_hand WHERE username=login) = 9) THEN -- можно взять из колоды и закончить ход
                    INSERT INTO Cards_in_hand (card_id, username) SELECT card_id, login FROM Decks where game_id=c_g and card_id  NOT IN(SELECT card_id FROM Cards_in_hand where game_id=c_g) and card_id!=(select card_on_table from Games where game_id=c_g) order by RAND() limit 1;
                    UPDATE Turns SET current_player = (SELECT next_player FROM Players WHERE username=login) WHERE current_player=login;
                    IF ((SELECT rank FROM Games, Cards NATURAL JOIN Card_type WHERE game_id=(SELECT game_id FROM Players WHERE username=login) and card_on_table=card_id)=14) THEN
                         UPDATE Turns SET current_player = (SELECT next_player FROM Players WHERE username=current_player) WHERE current_player=(SELECT next_player FROM Players WHERE username=login);
                    END IF;
            END if;
        ELSEIF (c='table') THEN
            IF ((SELECT COUNT(card_id) FROM Cards_in_hand WHERE username=login) = 10 ) THEN -- можно взять со стола
                    INSERT INTO Cards_in_hand (card_id, username) select card_on_table, login from Games where game_id=c_g; -- добавить карту в руку со стола 
            ELSEIF ((SELECT COUNT(card_id) FROM Cards_in_hand WHERE username=login) = 9) THEN -- можно взять только из колоды
                    SELECT "Sorry", "You can take card from deck(1)";
            END IF; 
        ELSE
            SELECT "Sorry", "Select deck(1) or table(2)";
        END IF;
    END IF;

END//


-- p_card: place card
DELIMITER //

CREATE PROCEDURE p_card(login VARCHAR(30), pw VARCHAR(20), c INT)
BEGIN
    DECLARE c_g INT;
    SET c_g=(select game_id from Players where username=login);
    IF ((SELECT COUNT(*) from Users WHERE username=login and u_password=pw) = 0) THEN
        SELECT "Error", "Wrong password";
    ELSEIF ((SELECT COUNT(*) FROM Players WHERE username=login) = 0) THEN
        SELECT "Error", "Connect to game or create new first";
    ELSEIF ((SELECT COUNT(card_on_table) FROM Games WHERE game_id=c_g) = 0) THEN
        SELECT "Error","Waiting for players", 
        (SELECT COUNT(username) as players_in_game FROM Players WHERE game_id=c_g) as players_in_game;
    ELSEIF ((SELECT current_player FROM Turns, Players WHERE game_id=c_g and current_player=username) != login) THEN
        SELECT "Error", (SELECT current_player FROM Turns, Players WHERE game_id=c_g and current_player=username) as current_player, (SELECT card_on_table FROM Games WHERE game_id=c_g) as card_on_table;
    ELSE                
        IF ((SELECT COUNT(*) from Cards_in_hand WHERE card_id=c AND username=login)=0) THEN
            SELECT "Oops!", "Wrong card id";
        end IF;
        IF ((SELECT COUNT(*) from Cards_in_hand WHERE username=login) = 11 ) THEN
            UPDATE Games SET card_on_table = c WHERE game_id=c_g;
            DELETE FROM Cards_in_hand WHERE card_id=c AND username=login;
            UPDATE Turns SET current_player = (SELECT next_player FROM Players WHERE username=login) WHERE current_player=login;
            IF ((SELECT rank FROM Cards NATURAL JOIN Card_type WHERE card_id=c)=14) THEN
                UPDATE Turns SET current_player = (SELECT next_player FROM Players WHERE username=current_player) WHERE current_player=(SELECT next_player FROM Players WHERE username=login);
            END IF;
            CALL game_state(login, pw);
        ELSEIF ((SELECT COUNT(*) from Cards_in_hand WHERE username=login) = 10 ) THEN
            UPDATE Games SET card_on_table = c WHERE game_id=c_g;
            DELETE FROM Cards_in_hand WHERE card_id=c;
            SELECT c as card_on_table, "Call t_card to finish your turn";
        ELSEIF ((SELECT COUNT(*) from Cards_in_hand WHERE username=login) = 9 ) THEN
            SELECT "You already did this", "Call t_card to finish your turn";
        END if;
    END IF;

END //

-- phase1

DELIMITER //

CREATE PROCEDURE phase1(login VARCHAR(30), pw VARCHAR(20), c1 INT, c2 INT,c3 INT,c4 INT,c5 INT,c6 INT)
BEGIN
    DECLARE pl INT;
    DECLARE pt INT;
    CREATE TEMPORARY TABLE c_phase(card_id int, id int, rank int, color VARCHAR(10), username VARCHAR(30));
    CREATE TEMPORARY TABLE Card1(cid INT);
    CREATE TEMPORARY TABLE Card2(cidx INT, un VARCHAR(30), id int PRIMARY KEY AUTO_INCREMENT);
    CREATE TEMPORARY TABLE Card3(cid INT, id int PRIMARY KEY AUTO_INCREMENT);
    
    
    IF ((SELECT COUNT(*) from Users WHERE username=login and u_password=pw) = 0) THEN
        SELECT "Error", "Wrong password";
    ELSEIF ((SELECT COUNT(*) FROM Players WHERE username=login) = 0) THEN
        SELECT "Error", "Connect to game or create new first";
    ELSEIF ((SELECT COUNT(card_on_table) FROM Games WHERE game_id=(select game_id from Players where username=login)) = 0) THEN
        SELECT "Waiting for players", (SELECT COUNT(username) as players_in_game FROM Players WHERE game_id=(select game_id from Players where username=login)) 
        as players_in_game;
    ELSEIF ((SELECT COUNT(*) FROM Turns WHERE current_player=login) = 0) THEN
        SELECT "Error", "Wait for your turn";
    ELSEIF ((SELECT game_phase FROM Games WHERE game_id=(select game_id from Players where username=login)) != 1) THEN
        SELECT "Sorry", (SELECT game_phase FROM Games WHERE game_id=(select game_id from Players where username=login)) as cur_phase;
    ELSE

        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c1 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c2 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c3 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c4 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c5 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c6 and Cards_in_hand.username = login;
        
        IF ((SELECT count(DISTINCT id) FROM c_phase WHERE username=login) != 6) THEN          
            drop table c_phase;
            SELECT 'Something wrong with your cards';
        else                      
        
        IF ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1) > 12) THEN 
            SELECT 'Error', 'Combination starts with card from 1 to 12, not jocker';
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c2) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1)) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c2) != 13)) THEN
            SELECT 'Error', 'Troubles with second card';
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c3) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1)) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c3) != 13)) THEN
            SELECT 'Error', 'Troubles with third card';
        ELSEIF ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c4) > 12) THEN 
            SELECT 'Error', 'Combination stats for 1 to 12, not jocker';
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c5) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c4)) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c5) != 13)) THEN
            SELECT 'Error', 'Troubles with fifth card';
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c6) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c4)) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c6) != 13)) THEN
            SELECT 'Error', 'Troubles with fifth card';   
        ELSE
                   SET pt = ((2*(SELECT game_phase from Games WHERE game_id=(select game_id from Players where username=login)))-1);
            UPDATE Players SET points = points+pt WHERE username=login;
            if ((select count(*) from Cards_in_hand where username=login) = 11) THEN
               UPDATE Games SET card_on_table = (SELECT distinct Decks.card_id FROM Decks, Cards_in_hand where game_id=(select game_id from Players where username=login) and Decks.card_id  NOT IN(SELECT card_id FROM Cards_in_hand where game_id=(select game_id from Players where username=login))  order by RAND() limit 1) WHERE (game_id=(select game_id from Players where username=login)); --todo
            end if;
            UPDATE Games SET game_phase=game_phase+1 WHERE game_id=(select game_id from Players where username=login);
            SET pl = (SELECT count(*) FROM Players WHERE game_id=(select game_id from Players where username=login))*10;
            INSERT INTO Card1(cid) SELECT card_id FROM Decks WHERE game_id=(select game_id from Players where username=login) ORDER by rand() limit 10;         
            INSERT into Card2(cidx, un) SELECT cid, username FROM Card1 cross join Players WHERE game_id=(select game_id from Players where username=login);                    INSERT INTO Card3(cid) SELECT card_id FROM Decks WHERE game_id=(select game_id from Players where username=login) and card_id!=(SELECT card_on_table from Games WHERE game_id=(SELECT game_id FROM Players WHERE username=login)) ORDER by rand() limit pl;         
            DELETE FROM Cards_in_hand WHERE EXISTS (SELECT username FROM Players WHERE game_id= (SELECT game_id FROM Players WHERE username=login));        
            INSERT INTO Cards_in_hand (card_id, username) SELECT cid, un FROM Card2 d1 inner join Card3 d2 on d1.id = d2.id;  
            UPDATE Turns SET current_player = (SELECT next_player FROM Players WHERE username=login) WHERE current_player=login;
            SELECT 'You get points!';
        end if;
        end if;
    END IF;
    
END//

-- phase2
DELIMITER //

CREATE PROCEDURE phase2(login VARCHAR(30), pw VARCHAR(20), c1 INT, c2 INT,c3 INT,c4 INT,c5 INT)
BEGIN
    DECLARE pl INT;
    DECLARE pt INT;
    CREATE TEMPORARY TABLE c_phase(card_id int, id int, rank int, color VARCHAR(10), username VARCHAR(30));
    CREATE TEMPORARY TABLE Card1(cid INT);
    CREATE TEMPORARY TABLE Card2(cidx INT, un VARCHAR(30), id int PRIMARY KEY AUTO_INCREMENT);
    CREATE TEMPORARY TABLE Card3(cid INT, id int PRIMARY KEY AUTO_INCREMENT);
    
    
    IF ((SELECT COUNT(*) from Users WHERE username=login and u_password=pw) = 0) THEN
        SELECT "Error", "Wrong password";
    ELSEIF ((SELECT COUNT(*) FROM Players WHERE username=login) = 0) THEN
        SELECT "Error", "Connect to game or create new first";
    ELSEIF ((SELECT COUNT(card_on_table) FROM Games WHERE game_id=(select game_id from Players where username=login)) = 0) THEN
        SELECT "Waiting for players", (SELECT COUNT(username) as players_in_game FROM Players WHERE game_id=(select game_id from Players where username=login)) 
        as players_in_game;
    ELSEIF ((SELECT game_phase FROM Games WHERE game_id=(select game_id from Players where username=login)) != 2) THEN
        SELECT "Sorry", (SELECT game_phase FROM Games WHERE game_id=(select game_id from Players where username=login)) as cur_phase;
    ELSE                         
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c1 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c2 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c3 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c4 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c5 and Cards_in_hand.username = login;
        
        
        IF ((SELECT count(DISTINCT id) FROM c_phase WHERE username=login) != 5) THEN          
            drop table c_phase;
            SELECT 'Something wrong with your cards';
        else                       
        
        IF ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1) > 12) THEN 
            SELECT 'Error', 'Combination stats for 1 to 12, not jocker';
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c2) != ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1)+1)) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c2) != 13)) THEN
            SELECT 'Error', 'Troubles with second card';
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c3) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1)+2) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c3) != 13)) THEN
            SELECT 'Error', 'Troubles with third card';
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c4) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1)+3) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c4) != 13)) THEN
            SELECT 'Error', 'Troubles with fourth card';
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c5) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1)+4) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c5) != 13)) THEN
            SELECT 'Error', 'Troubles with fifth card';  
        ELSE
            SET pt = ((2*(SELECT game_phase from Games WHERE game_id=(select game_id from Players where username=login)))-1);
            UPDATE Players SET points = points+pt WHERE username=login;
            UPDATE Games SET game_phase=game_phase+1 WHERE game_id=(select game_id from Players where username=login);
            SET pl = (SELECT count(*) FROM Players WHERE game_id=(select game_id from Players where username=login))*10;
            INSERT INTO Card1(cid) SELECT card_id FROM Decks WHERE game_id=(select game_id from Players where username=login) ORDER by rand() limit 10;         
            INSERT into Card2(cidx, un) SELECT cid, username FROM Card1 cross join Players WHERE game_id=(select game_id from Players where username=login);                    INSERT INTO Card3(cid) SELECT card_id FROM Decks WHERE game_id=(select game_id from Players where username=login) and card_id!=(SELECT card_on_table from Games WHERE game_id=(SELECT game_id FROM Players WHERE username=login)) ORDER by rand() limit pl;         
            DELETE FROM Cards_in_hand WHERE EXISTS (SELECT username FROM Players WHERE game_id= (SELECT game_id FROM Players WHERE username=login));        
            INSERT INTO Cards_in_hand (card_id, username) SELECT cid, un FROM Card2 d1 inner join Card3 d2 on d1.id = d2.id;  
            UPDATE Turns SET current_player = (SELECT next_player FROM Players WHERE username=login) WHERE current_player=login;
            SELECT 'You get points!';
        end if;
        end if;
    END IF;
    
END//

-- phase3
DELIMITER //

CREATE PROCEDURE phase3(login VARCHAR(30), pw VARCHAR(20), c1 INT, c2 INT,c3 INT,c4 INT,c5 INT)
BEGIN
    DECLARE pl INT;
    DECLARE pt INT;
    CREATE TEMPORARY TABLE c_phase(card_id int, id int, rank int, color VARCHAR(10), username VARCHAR(30));
    CREATE TEMPORARY TABLE Card1(cid INT);
    CREATE TEMPORARY TABLE Card2(cidx INT, un VARCHAR(30), id int PRIMARY KEY AUTO_INCREMENT);
    CREATE TEMPORARY TABLE Card3(cid INT, id int PRIMARY KEY AUTO_INCREMENT);
    
    
    IF ((SELECT COUNT(*) from Users WHERE username=login and u_password=pw) = 0) THEN
        SELECT "Error", "Wrong password";
    ELSEIF ((SELECT COUNT(*) FROM Players WHERE username=login) = 0) THEN
        SELECT "Error", "Connect to game or create new first";
    ELSEIF ((SELECT COUNT(card_on_table) FROM Games WHERE game_id=(select game_id from Players where username=login)) = 0) THEN
        SELECT "Waiting for players", (SELECT COUNT(username) as players_in_game FROM Players WHERE game_id=(select game_id from Players where username=login)) 
        as players_in_game;
    ELSEIF ((SELECT game_phase FROM Games WHERE game_id=(select game_id from Players where username=login)) != 3) THEN
        SELECT "Sorry", (SELECT game_phase FROM Games WHERE game_id=(select game_id from Players where username=login)) as cur_phase;
    ELSE                         
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c1 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c2 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c3 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c4 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c5 and Cards_in_hand.username = login;
        
        IF ((SELECT count(DISTINCT id) FROM c_phase WHERE username=login) != 5) THEN             DELETE FROM c_phase WHERE username=login;
            SELECT 'Something wrong with your cards';
        else
        
        IF ((select color from Cards_in_hand natural join Cards natural join Card_type where card_id=c1) = 'blue') THEN 
            SELECT 'Error', 'Combination starts not from blue card';
        ELSEIF (  ( (select Count(*) from Cards_in_hand natural join Cards natural join Card_type where card_id= c2 and color=(select color from Cards_in_hand natural join Cards natural join Card_type where card_id= c1))=0 ) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c2) != 13)) THEN
            SELECT 'Error', 'Troubles with second card';
        ELSEIF (( (select Count(*) from Cards_in_hand natural join Cards natural join Card_type where card_id= c3 and color=(select color from Cards_in_hand natural join Cards natural join Card_type where card_id= c1))=0 ) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c3) != 13)) THEN
            SELECT 'Error', 'Troubles with third card';
        ELSEIF (( (select Count(*) from Cards_in_hand natural join Cards natural join Card_type where card_id= c4 and color=(select color from Cards_in_hand natural join Cards natural join Card_type where card_id= c1))=0 ) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c4) != 13)) THEN
            SELECT 'Error', 'Troubles with fourth card';
        ELSEIF (( (select Count(*) from Cards_in_hand natural join Cards natural join Card_type where card_id= c5 and color=(select color from Cards_in_hand natural join Cards natural join Card_type where card_id= c1))=0 ) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c5) != 13)) THEN
            SELECT 'Error', 'Troubles with fifth card';  
        ELSE
                    SET pt = ((2*(SELECT game_phase from Games WHERE game_id=(select game_id from Players where username=login)))-1);
            UPDATE Players SET points = points+pt WHERE username=login;
            UPDATE Games SET game_phase=game_phase+1 WHERE game_id=(select game_id from Players where username=login);
            SET pl = (SELECT count(*) FROM Players WHERE game_id=(select game_id from Players where username=login))*10;
            INSERT INTO Card1(cid) SELECT card_id FROM Decks WHERE game_id=(select game_id from Players where username=login) ORDER by rand() limit 10;         
            INSERT into Card2(cidx, un) SELECT cid, username FROM Card1 cross join Players WHERE game_id=(select game_id from Players where username=login);                    INSERT INTO Card3(cid) SELECT card_id FROM Decks WHERE game_id=(select game_id from Players where username=login) and card_id!=(SELECT card_on_table from Games WHERE game_id=(SELECT game_id FROM Players WHERE username=login)) ORDER by rand() limit pl;         
            DELETE FROM Cards_in_hand WHERE EXISTS (SELECT username FROM Players WHERE game_id= (SELECT game_id FROM Players WHERE username=login));        
            INSERT INTO Cards_in_hand (card_id, username) SELECT cid, un FROM Card2 d1 inner join Card3 d2 on d1.id = d2.id;  
            UPDATE Turns SET current_player = (SELECT next_player FROM Players WHERE username=login) WHERE current_player=login;
            SELECT 'You get points!';
        end if;
        end if;
    END IF;
    
END//

-- phase4
DELIMITER //

CREATE PROCEDURE phase4(login VARCHAR(30), pw VARCHAR(20), c1 INT, c2 INT,c3 INT,c4 INT,c5 INT,c6 INT,c7 INT)
BEGIN
    DECLARE pl INT;
    DECLARE pt INT;
    CREATE TEMPORARY TABLE c_phase(card_id int, id int, rank int, color VARCHAR(10), username VARCHAR(30));
    CREATE TEMPORARY TABLE Card1(cid INT);
    CREATE TEMPORARY TABLE Card2(cidx INT, un VARCHAR(30), id int PRIMARY KEY AUTO_INCREMENT);
    CREATE TEMPORARY TABLE Card3(cid INT, id int PRIMARY KEY AUTO_INCREMENT);
    
    
    IF ((SELECT COUNT(*) from Users WHERE username=login and u_password=pw) = 0) THEN
        SELECT "Error", "Wrong password";
    ELSEIF ((SELECT COUNT(*) FROM Players WHERE username=login) = 0) THEN
        SELECT "Error", "Connect to game or create new first";
    ELSEIF ((SELECT COUNT(card_on_table) FROM Games WHERE game_id=(select game_id from Players where username=login)) = 0) THEN
        SELECT "Waiting for players", (SELECT COUNT(username) as players_in_game FROM Players WHERE game_id=(select game_id from Players where username=login)) 
        as players_in_game;
    ELSEIF ((SELECT COUNT(*) FROM Turns WHERE current_player=login) = 0) THEN
        SELECT "Error", "Wait for your turn";
    ELSEIF ((SELECT game_phase FROM Games WHERE game_id=(select game_id from Players where username=login)) != 4) THEN
        SELECT "Sorry", (SELECT game_phase FROM Games WHERE game_id=(select game_id from Players where username=login)) as cur_phase;
    ELSE                         
        
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c1 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c2 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c3 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c4 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c5 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c6 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c7 and Cards_in_hand.username = login;
        
        
        IF ((SELECT count(DISTINCT id) FROM c_phase WHERE username=login) != 7) THEN          
            drop table c_phase;
            SELECT 'Something wrong with your cards';
        else                      
        
        IF ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1) > 12) THEN 
            SELECT 'Error', 'Combination stats for 1 to 12, not jocker';
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c2) != ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1)+1)) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c2) != 13)) THEN
            SELECT 'Error', 'Troubles with second card';
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c3) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1)+2) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c3) != 13)) THEN
            SELECT 'Error', 'Troubles with third card';
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c4) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1)+3) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c4) != 13)) THEN
            SELECT 'Error', 'Troubles with fourth card';
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c5) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1)+4) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c5) != 13)) THEN
            SELECT 'Error', 'Troubles with fifth card';  
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c6) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1)+5) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c6) != 13)) THEN
            SELECT 'Error', 'Troubles with sixth card'; 
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c7) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1)+6) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c7) != 13)) THEN
            SELECT 'Error', 'Troubles with seventh card'; 
        ELSE
            SET pt = ((2*(SELECT game_phase from Games WHERE game_id=(select game_id from Players where username=login)))-1);
            UPDATE Players SET points = points+pt WHERE username=login;
            UPDATE Games SET game_phase=game_phase+1 WHERE game_id=(select game_id from Players where username=login);
            SET pl = (SELECT count(*) FROM Players WHERE game_id=(select game_id from Players where username=login))*10;
            INSERT INTO Card1(cid) SELECT card_id FROM Decks WHERE game_id=(select game_id from Players where username=login) ORDER by rand() limit 10;         
            INSERT into Card2(cidx, un) SELECT cid, username FROM Card1 cross join Players WHERE game_id=(select game_id from Players where username=login);                    INSERT INTO Card3(cid) SELECT card_id FROM Decks WHERE game_id=(select game_id from Players where username=login) and card_id!=(SELECT card_on_table from Games WHERE game_id=(SELECT game_id FROM Players WHERE username=login)) ORDER by rand() limit pl;         
            DELETE FROM Cards_in_hand WHERE EXISTS (SELECT username FROM Players WHERE game_id= (SELECT game_id FROM Players WHERE username=login));        
            INSERT INTO Cards_in_hand (card_id, username) SELECT cid, un FROM Card2 d1 inner join Card3 d2 on d1.id = d2.id;  
            UPDATE Turns SET current_player = (SELECT next_player FROM Players WHERE username=login) WHERE current_player=login;
            SELECT 'You get points!';
        end if;        
        end if;
    END IF;
    
END//


-- phase5
DELIMITER //

CREATE PROCEDURE phase5(login VARCHAR(30), pw VARCHAR(20), c1 INT, c2 INT,c3 INT,c4 INT,c5 INT,c6 INT,c7 INT, c8 INT)
BEGIN
    DECLARE pl INT;
    DECLARE pt INT;
    CREATE TEMPORARY TABLE c_phase(card_id int, id int, rank int, color VARCHAR(10), username VARCHAR(30));
    CREATE TEMPORARY TABLE Card1(cid INT);
    CREATE TEMPORARY TABLE Card2(cidx INT, un VARCHAR(30), id int PRIMARY KEY AUTO_INCREMENT);
    CREATE TEMPORARY TABLE Card3(cid INT, id int PRIMARY KEY AUTO_INCREMENT);
    
    
    IF ((SELECT COUNT(*) from Users WHERE username=login and u_password=pw) = 0) THEN
        SELECT "Error", "Wrong password";
    ELSEIF ((SELECT COUNT(*) FROM Players WHERE username=login) = 0) THEN
        SELECT "Error", "Connect to game or create new first";
    ELSEIF ((SELECT COUNT(card_on_table) FROM Games WHERE game_id=(select game_id from Players where username=login)) = 0) THEN
        SELECT "Waiting for players", (SELECT COUNT(username) as players_in_game FROM Players WHERE game_id=(select game_id from Players where username=login)) 
        as players_in_game;
    ELSEIF ((SELECT COUNT(*) FROM Turns WHERE current_player=login) = 0) THEN
        SELECT "Error", "Wait for your turn";
    ELSEIF ((SELECT game_phase FROM Games WHERE game_id=(select game_id from Players where username=login)) != 5) THEN
        SELECT "Sorry", (SELECT game_phase FROM Games WHERE game_id=(select game_id from Players where username=login)) as cur_phase;
    ELSE                         
        
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c1 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c2 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c3 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c4 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c5 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c6 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c7 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c8 and Cards_in_hand.username = login;
        
        
        IF ((SELECT count(DISTINCT id) FROM c_phase WHERE username=login) != 8) THEN          
            drop table c_phase;
            SELECT 'Something wrong with your cards';
        else                       
        
        IF ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1) > 12) THEN 
            SELECT 'Error', 'Combination stats for 1 to 12, not jocker';
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c2) != ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1)+1)) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c2) != 13)) THEN
            SELECT 'Error', 'Troubles with second card';
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c3) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1)+2) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c3) != 13)) THEN
            SELECT 'Error', 'Troubles with third card';
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c4) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1)+3) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c4) != 13)) THEN
            SELECT 'Error', 'Troubles with fourth card';
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c5) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1)+4) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c5) != 13)) THEN
            SELECT 'Error', 'Troubles with fifth card';  
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c6) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1)+5) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c6) != 13)) THEN
            SELECT 'Error', 'Troubles with sixth card'; 
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c7) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1)+6) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c7) != 13)) THEN
            SELECT 'Error', 'Troubles with seventh card'; 
         ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c8) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1)+7) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c8) != 13)) THEN
            SELECT 'Error', 'Troubles with eighth card'; 
        ELSE
            SET pt = ((2*(SELECT game_phase from Games WHERE game_id=(select game_id from Players where username=login)))-1);
            UPDATE Players SET points = points+pt WHERE username=login;
            UPDATE Games SET game_phase=game_phase+1 WHERE game_id=(select game_id from Players where username=login);
            SET pl = (SELECT count(*) FROM Players WHERE game_id=(select game_id from Players where username=login))*10;
            INSERT INTO Card1(cid) SELECT card_id FROM Decks WHERE game_id=(select game_id from Players where username=login) ORDER by rand() limit 10;         
            INSERT into Card2(cidx, un) SELECT cid, username FROM Card1 cross join Players WHERE game_id=(select game_id from Players where username=login);                    INSERT INTO Card3(cid) SELECT card_id FROM Decks WHERE game_id=(select game_id from Players where username=login) and card_id!=(SELECT card_on_table from Games WHERE game_id=(SELECT game_id FROM Players WHERE username=login)) ORDER by rand() limit pl;         
            DELETE FROM Cards_in_hand WHERE EXISTS (SELECT username FROM Players WHERE game_id= (SELECT game_id FROM Players WHERE username=login));        
            INSERT INTO Cards_in_hand (card_id, username) SELECT cid, un FROM Card2 d1 inner join Card3 d2 on d1.id = d2.id;  
            UPDATE Turns SET current_player = (SELECT next_player FROM Players WHERE username=login) WHERE current_player=login;
            SELECT 'You get points!';
        end if;        
        end if;
    END IF;
    
END//




-- phase6
DELIMITER //

CREATE PROCEDURE phase6(login VARCHAR(30), pw VARCHAR(20), c1 INT, c2 INT,c3 INT,c4 INT,c5 INT,c6 INT, c7 INT, c8 INT)
BEGIN
    DECLARE pl INT;
    DECLARE pt INT;
    CREATE TEMPORARY TABLE c_phase(card_id int, id int, rank int, color VARCHAR(10), username VARCHAR(30));
    CREATE TEMPORARY TABLE Card1(cid INT);
    CREATE TEMPORARY TABLE Card2(cidx INT, un VARCHAR(30), id int PRIMARY KEY AUTO_INCREMENT);
    CREATE TEMPORARY TABLE Card3(cid INT, id int PRIMARY KEY AUTO_INCREMENT);
    
    
    IF ((SELECT COUNT(*) from Users WHERE username=login and u_password=pw) = 0) THEN
        SELECT "Error", "Wrong password";
    ELSEIF ((SELECT COUNT(*) FROM Players WHERE username=login) = 0) THEN
        SELECT "Error", "Connect to game or create new first";
    ELSEIF ((SELECT COUNT(card_on_table) FROM Games WHERE game_id=(select game_id from Players where username=login)) = 0) THEN
        SELECT "Waiting for players", (SELECT COUNT(username) as players_in_game FROM Players WHERE game_id=(select game_id from Players where username=login)) 
        as players_in_game;
    ELSEIF ((SELECT COUNT(*) FROM Turns WHERE current_player=login) = 0) THEN
        SELECT "Error", "Wait for your turn";
    ELSEIF ((SELECT game_phase FROM Games WHERE game_id=(select game_id from Players where username=login)) != 6) THEN
        SELECT "Sorry", (SELECT game_phase FROM Games WHERE game_id=(select game_id from Players where username=login)) as cur_phase;
    ELSE

        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c1 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c2 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c3 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c4 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c5 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c6 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c7 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c8 and Cards_in_hand.username = login;
        
        IF ((SELECT count(DISTINCT id) FROM c_phase WHERE username=login) != 8) THEN          
            drop table c_phase;
            SELECT 'Something wrong with your cards';
        else                       
        
        IF ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1) > 12) THEN 
            SELECT 'Error', 'Combination starts with card from 1 to 12, not jocker';
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c2) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1)) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c2) != 13)) THEN
            SELECT 'Error', 'Troubles with second card';
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c3) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1)) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c3) != 13)) THEN
            SELECT 'Error', 'Troubles with third card';
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c4) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1)) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c4) != 13)) THEN
            SELECT 'Error', 'Troubles with fourth card';
        ELSEIF ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c5) > 12) THEN 
            SELECT 'Error', 'Combination stats for 1 to 12, not jocker';
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c6) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c5)) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c6) != 13)) THEN
            SELECT 'Error', 'Troubles with fifth card';
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c7) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c5)) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c7) != 13)) THEN
            SELECT 'Error', 'Troubles with fifth card';
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c8) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c5)) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c8) != 13)) THEN
            SELECT 'Error', 'Troubles with fifth card';
        ELSE
                   SET pt = ((2*(SELECT game_phase from Games WHERE game_id=(select game_id from Players where username=login)))-1);
            UPDATE Players SET points = points+pt WHERE username=login;
            UPDATE Games SET game_phase=game_phase+1 WHERE game_id=(select game_id from Players where username=login);
            SET pl = (SELECT count(*) FROM Players WHERE game_id=(select game_id from Players where username=login))*10;
            INSERT INTO Card1(cid) SELECT card_id FROM Decks WHERE game_id=(select game_id from Players where username=login) ORDER by rand() limit 10;         
            INSERT into Card2(cidx, un) SELECT cid, username FROM Card1 cross join Players WHERE game_id=(select game_id from Players where username=login);                    INSERT INTO Card3(cid) SELECT card_id FROM Decks WHERE game_id=(select game_id from Players where username=login) and card_id!=(SELECT card_on_table from Games WHERE game_id=(SELECT game_id FROM Players WHERE username=login)) ORDER by rand() limit pl;         
            DELETE FROM Cards_in_hand WHERE EXISTS (SELECT username FROM Players WHERE game_id= (SELECT game_id FROM Players WHERE username=login));        
            INSERT INTO Cards_in_hand (card_id, username) SELECT cid, un FROM Card2 d1 inner join Card3 d2 on d1.id = d2.id;  
            UPDATE Turns SET current_player = (SELECT next_player FROM Players WHERE username=login) WHERE current_player=login;
            SELECT 'You get points!';
        end if;
        end if;
    END IF;
    
END//


-- phase7
DELIMITER //

CREATE PROCEDURE phase7(login VARCHAR(30), pw VARCHAR(20), c1 INT, c2 INT,c3 INT,c4 INT,c5 INT,c6 INT,c7 INT, c8 INT, c9 INT)
BEGIN
    DECLARE pl INT;
    DECLARE pt INT;
    CREATE TEMPORARY TABLE c_phase(card_id int, id int, rank int, color VARCHAR(10), username VARCHAR(30));
    CREATE TEMPORARY TABLE Card1(cid INT);
    CREATE TEMPORARY TABLE Card2(cidx INT, un VARCHAR(30), id int PRIMARY KEY AUTO_INCREMENT);
    CREATE TEMPORARY TABLE Card3(cid INT, id int PRIMARY KEY AUTO_INCREMENT);
    
    
    IF ((SELECT COUNT(*) from Users WHERE username=login and u_password=pw) = 0) THEN
        SELECT "Error", "Wrong password";
    ELSEIF ((SELECT COUNT(*) FROM Players WHERE username=login) = 0) THEN
        SELECT "Error", "Connect to game or create new first";
    ELSEIF ((SELECT COUNT(card_on_table) FROM Games WHERE game_id=(select game_id from Players where username=login)) = 0) THEN
        SELECT "Waiting for players", (SELECT COUNT(username) as players_in_game FROM Players WHERE game_id=(select game_id from Players where username=login)) 
        as players_in_game;
    ELSEIF ((SELECT COUNT(*) FROM Turns WHERE current_player=login) = 0) THEN
        SELECT "Error", "Wait for your turn";
    ELSEIF ((SELECT game_phase FROM Games WHERE game_id=(select game_id from Players where username=login)) != 7) THEN
        SELECT "Sorry", (SELECT game_phase FROM Games WHERE game_id=(select game_id from Players where username=login)) as cur_phase;
    ELSE                         
        
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c1 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c2 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c3 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c4 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c5 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c6 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c7 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c8 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c9 and Cards_in_hand.username = login;
        
        
        IF ((SELECT count(DISTINCT id) FROM c_phase WHERE username=login) != 9) THEN          
            drop table c_phase;
            SELECT 'Something wrong with your cards';
        ELSE                       
        
        IF ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1) > 12) THEN 
            SELECT 'Error', 'Combination stats for 1 to 12, not jocker';
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c2) != ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1)+1)) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c2) != 13)) THEN
            SELECT 'Error', 'Troubles with second card';
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c3) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1)+2) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c3) != 13)) THEN
            SELECT 'Error', 'Troubles with third card';
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c4) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1)+3) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c4) != 13)) THEN
            SELECT 'Error', 'Troubles with fourth card';
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c5) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1)+4) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c5) != 13)) THEN
            SELECT 'Error', 'Troubles with fifth card';  
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c6) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1)+5) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c6) != 13)) THEN
            SELECT 'Error', 'Troubles with sixth card'; 
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c7) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1)+6) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c7) != 13)) THEN
            SELECT 'Error', 'Troubles with seventh card'; 
         ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c8) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1)+7) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c8) != 13)) THEN
            SELECT 'Error', 'Troubles with eighth card'; 
         ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c9) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1)+8) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c9) != 13)) THEN
            SELECT 'Error', 'Troubles with eighth card';
        ELSE
            SET pt = ((2*(SELECT game_phase from Games WHERE game_id=(select game_id from Players where username=login)))-1);
            UPDATE Players SET points = points+pt WHERE username=login;
            UPDATE Games SET game_phase=game_phase+1 WHERE game_id=(select game_id from Players where username=login);
            SET pl = (SELECT count(*) FROM Players WHERE game_id=(select game_id from Players where username=login))*10;
            INSERT INTO Card1(cid) SELECT card_id FROM Decks WHERE game_id=(select game_id from Players where username=login) ORDER by rand() limit 10;         
            INSERT into Card2(cidx, un) SELECT cid, username FROM Card1 cross join Players WHERE game_id=(select game_id from Players where username=login);                    INSERT INTO Card3(cid) SELECT card_id FROM Decks WHERE game_id=(select game_id from Players where username=login) and card_id!=(SELECT card_on_table from Games WHERE game_id=(SELECT game_id FROM Players WHERE username=login)) ORDER by rand() limit pl;         
            DELETE FROM Cards_in_hand WHERE EXISTS (SELECT username FROM Players WHERE game_id= (SELECT game_id FROM Players WHERE username=login));        
            INSERT INTO Cards_in_hand (card_id, username) SELECT cid, un FROM Card2 d1 inner join Card3 d2 on d1.id = d2.id;  
            UPDATE Turns SET current_player = (SELECT next_player FROM Players WHERE username=login) WHERE current_player=login;
            SELECT 'You get points!';
        end if;        
        end if;
    END IF;
    
END //


-- phase8
DELIMITER //

CREATE PROCEDURE phase8(login VARCHAR(30), pw VARCHAR(20), c1 INT, c2 INT,c3 INT,c4 INT,c5 INT,c6 INT, c7 INT)
BEGIN
    DECLARE pl INT;
    DECLARE pt INT;
    CREATE TEMPORARY TABLE c_phase(card_id int, id int, rank int, color VARCHAR(10), username VARCHAR(30));
    CREATE TEMPORARY TABLE Card1(cid INT);
    CREATE TEMPORARY TABLE Card2(cidx INT, un VARCHAR(30), id int PRIMARY KEY AUTO_INCREMENT);
    CREATE TEMPORARY TABLE Card3(cid INT, id int PRIMARY KEY AUTO_INCREMENT);
    
    
    IF ((SELECT COUNT(*) from Users WHERE username=login and u_password=pw) = 0) THEN
        SELECT "Error", "Wrong password";
    ELSEIF ((SELECT COUNT(*) FROM Players WHERE username=login) = 0) THEN
        SELECT "Error", "Connect to game or create new first";
    ELSEIF ((SELECT COUNT(card_on_table) FROM Games WHERE game_id=(select game_id from Players where username=login)) = 0) THEN
        SELECT "Waiting for players", (SELECT COUNT(username) as players_in_game FROM Players WHERE game_id=(select game_id from Players where username=login)) 
        as players_in_game;
    ELSEIF ((SELECT game_phase FROM Games WHERE game_id=(select game_id from Players where username=login)) != 8) THEN
        SELECT "Sorry", (SELECT game_phase FROM Games WHERE game_id=(select game_id from Players where username=login)) as cur_phase;
    ELSE                         
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c1 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c2 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c3 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c4 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c5 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c6 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c7 and Cards_in_hand.username = login;
        
        IF ((SELECT count(DISTINCT id) FROM c_phase WHERE username=login) != 7) THEN             DELETE FROM c_phase WHERE username=login;
            SELECT 'Something wrong with your cards';
        else
        
        IF ((select color from Cards_in_hand natural join Cards natural join Card_type where card_id=c1) = 'blue') THEN 
            SELECT 'Error', 'Combination starts not from blue card';
        ELSEIF (  ( (select Count(*) from Cards_in_hand natural join Cards natural join Card_type where card_id= c2 and color=(select color from Cards_in_hand natural join Cards natural join Card_type where card_id= c1))=0 ) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c2) != 13)) THEN
            SELECT 'Error', 'Troubles with second card';
        ELSEIF (( (select Count(*) from Cards_in_hand natural join Cards natural join Card_type where card_id= c3 and color=(select color from Cards_in_hand natural join Cards natural join Card_type where card_id= c1))=0 ) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c3) != 13)) THEN
            SELECT 'Error', 'Troubles with third card';
        ELSEIF (( (select Count(*) from Cards_in_hand natural join Cards natural join Card_type where card_id= c4 and color=(select color from Cards_in_hand natural join Cards natural join Card_type where card_id= c1))=0 ) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c4) != 13)) THEN
            SELECT 'Error', 'Troubles with fourth card';
        ELSEIF (( (select Count(*) from Cards_in_hand natural join Cards natural join Card_type where card_id= c5 and color=(select color from Cards_in_hand natural join Cards natural join Card_type where card_id= c1))=0 ) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c5) != 13)) THEN
            SELECT 'Error', 'Troubles with fifth card';  
        ELSEIF (( (select Count(*) from Cards_in_hand natural join Cards natural join Card_type where card_id= c6 and color=(select color from Cards_in_hand natural join Cards natural join Card_type where card_id= c1))=0 ) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c6) != 13)) THEN
            SELECT 'Error', 'Troubles with sixth card';
        ELSEIF (( (select Count(*) from Cards_in_hand natural join Cards natural join Card_type where card_id= c7 and color=(select color from Cards_in_hand natural join Cards natural join Card_type where card_id= c1))=0 ) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c7) != 13)) THEN
            SELECT 'Error', 'Troubles with seventh card';
        ELSE
                    SET pt = ((2*(SELECT game_phase from Games WHERE game_id=(select game_id from Players where username=login)))-1);
            UPDATE Players SET points = points+pt WHERE username=login;
            UPDATE Games SET game_phase=game_phase+1 WHERE game_id=(select game_id from Players where username=login);
            SET pl = (SELECT count(*) FROM Players WHERE game_id=(select game_id from Players where username=login))*10;
            INSERT INTO Card1(cid) SELECT card_id FROM Decks WHERE game_id=(select game_id from Players where username=login) ORDER by rand() limit 10;         
            INSERT into Card2(cidx, un) SELECT cid, username FROM Card1 cross join Players WHERE game_id=(select game_id from Players where username=login);                    INSERT INTO Card3(cid) SELECT card_id FROM Decks WHERE game_id=(select game_id from Players where username=login) and card_id!=(SELECT card_on_table from Games WHERE game_id=(SELECT game_id FROM Players WHERE username=login)) ORDER by rand() limit pl;         
            DELETE FROM Cards_in_hand WHERE EXISTS (SELECT username FROM Players WHERE game_id= (SELECT game_id FROM Players WHERE username=login));        
            INSERT INTO Cards_in_hand (card_id, username) SELECT cid, un FROM Card2 d1 inner join Card3 d2 on d1.id = d2.id;  
            UPDATE Turns SET current_player = (SELECT next_player FROM Players WHERE username=login) WHERE current_player=login;
            SELECT 'You get points!';
        end if;
        end if;
    END IF;
    
END//

-- phase9

DELIMITER //

CREATE PROCEDURE phase9(login VARCHAR(30), pw VARCHAR(20), c1 INT, c2 INT,c3 INT,c4 INT,c5 INT,c6 INT, c7 INT, c8 INT, c9 INT)
BEGIN
    DECLARE pl INT;
    DECLARE pt INT;
    CREATE TEMPORARY TABLE c_phase(card_id int, id int, rank int, color VARCHAR(10), username VARCHAR(30));
    CREATE TEMPORARY TABLE Card1(cid INT);
    CREATE TEMPORARY TABLE Card2(cidx INT, un VARCHAR(30), id int PRIMARY KEY AUTO_INCREMENT);
    CREATE TEMPORARY TABLE Card3(cid INT, id int PRIMARY KEY AUTO_INCREMENT);
    
    
    IF ((SELECT COUNT(*) from Users WHERE username=login and u_password=pw) = 0) THEN
        SELECT "Error", "Wrong password";
    ELSEIF ((SELECT COUNT(*) FROM Players WHERE username=login) = 0) THEN
        SELECT "Error", "Connect to game or create new first";
    ELSEIF ((SELECT COUNT(card_on_table) FROM Games WHERE game_id=(select game_id from Players where username=login)) = 0) THEN
        SELECT "Waiting for players", (SELECT COUNT(username) as players_in_game FROM Players WHERE game_id=(select game_id from Players where username=login)) 
        as players_in_game;
    ELSEIF ((SELECT COUNT(*) FROM Turns WHERE current_player=login) = 0) THEN
        SELECT "Error", "Wait for your turn";
    ELSEIF ((SELECT game_phase FROM Games WHERE game_id=(select game_id from Players where username=login)) != 9) THEN
        SELECT "Sorry", (SELECT game_phase FROM Games WHERE game_id=(select game_id from Players where username=login)) as cur_phase;
    ELSE

        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c1 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c2 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c3 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c4 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c5 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c6 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c7 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c8 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c9 and Cards_in_hand.username = login;
        
        IF ((SELECT count(DISTINCT id) FROM c_phase WHERE username=login) != 9) THEN          
            drop table c_phase;
            SELECT 'Something wrong with your cards';
        else                      
        
        IF ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1) > 12) THEN 
            SELECT 'Error', 'Combination starts with card from 1 to 12, not jocker';
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c2) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1)) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c2) != 13)) THEN
            SELECT 'Error', 'Troubles with second card';
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c3) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1)) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c3) != 13)) THEN
            SELECT 'Error', 'Troubles with third card';
        ELSEIF ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c4) > 12) THEN 
            SELECT 'Error', 'Combination stats for 1 to 12, not jocker';
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c5) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c4)) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c5) != 13)) THEN
            SELECT 'Error', 'Troubles with fifth card';
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c6) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c4)) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c6) != 13)) THEN
            SELECT 'Error', 'Troubles with fifth card';
        ELSEIF ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c7) > 12) THEN 
            SELECT 'Error', 'Combination stats for 1 to 12, not jocker';
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c8) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c7)) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c8) != 13)) THEN
            SELECT 'Error', 'Troubles with fifth card';
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c9) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c7)) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c9) != 13)) THEN
            SELECT 'Error', 'Troubles with fifth card';
        ELSE
                   SET pt = ((2*(SELECT game_phase from Games WHERE game_id=(select game_id from Players where username=login)))-1);
            UPDATE Players SET points = points+pt WHERE username=login;
            UPDATE Games SET game_phase=game_phase+1 WHERE game_id=(select game_id from Players where username=login);
            SET pl = (SELECT count(*) FROM Players WHERE game_id=(select game_id from Players where username=login))*10;
            INSERT INTO Card1(cid) SELECT card_id FROM Decks WHERE game_id=(select game_id from Players where username=login) ORDER by rand() limit 10;         
            INSERT into Card2(cidx, un) SELECT cid, username FROM Card1 cross join Players WHERE game_id=(select game_id from Players where username=login);                    INSERT INTO Card3(cid) SELECT card_id FROM Decks WHERE game_id=(select game_id from Players where username=login) and card_id!=(SELECT card_on_table from Games WHERE game_id=(SELECT game_id FROM Players WHERE username=login)) ORDER by rand() limit pl;         
            DELETE FROM Cards_in_hand WHERE EXISTS (SELECT username FROM Players WHERE game_id= (SELECT game_id FROM Players WHERE username=login));        
            INSERT INTO Cards_in_hand (card_id, username) SELECT cid, un FROM Card2 d1 inner join Card3 d2 on d1.id = d2.id;  
            UPDATE Turns SET current_player = (SELECT next_player FROM Players WHERE username=login) WHERE current_player=login;
            SELECT 'You get points!';
        end if;
        end if;
    END IF;
    
END//

-- phase10

DELIMITER //

CREATE PROCEDURE phase10(login VARCHAR(30), pw VARCHAR(20), c1 INT, c2 INT,c3 INT,c4 INT,c5 INT,c6 INT,c7 INT, c8 INT)
BEGIN
    DECLARE pl INT;
    DECLARE pt INT;
    CREATE TEMPORARY TABLE c_phase(card_id int, id int, rank int, color VARCHAR(10), username VARCHAR(30));
    CREATE TEMPORARY TABLE Card1(cid INT);
    CREATE TEMPORARY TABLE Card2(cidx INT, un VARCHAR(30), id int PRIMARY KEY AUTO_INCREMENT);
    CREATE TEMPORARY TABLE Card3(cid INT, id int PRIMARY KEY AUTO_INCREMENT);
    
    
    IF ((SELECT COUNT(*) from Users WHERE username=login and u_password=pw) = 0) THEN
        SELECT "Error", "Wrong password";
    ELSEIF ((SELECT COUNT(*) FROM Players WHERE username=login) = 0) THEN
        SELECT "Error", "Connect to game or create new first";
    ELSEIF ((SELECT COUNT(card_on_table) FROM Games WHERE game_id=(select game_id from Players where username=login)) = 0) THEN
        SELECT "Waiting for players", (SELECT COUNT(username) as players_in_game FROM Players WHERE game_id=(select game_id from Players where username=login)) 
        as players_in_game;
    ELSEIF ((SELECT COUNT(*) FROM Turns WHERE current_player=login) = 0) THEN
        SELECT "Error", "Wait for your turn";
    ELSEIF ((SELECT game_phase FROM Games WHERE game_id=(select game_id from Players where username=login)) != 10) THEN
        SELECT "Sorry", (SELECT game_phase FROM Games WHERE game_id=(select game_id from Players where username=login)) as cur_phase;
    ELSE

        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c1 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c2 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c3 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c4 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c5 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c6 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c7 and Cards_in_hand.username = login;
        INSERT INTO c_phase (card_id, id, rank, color, username) select card_id, id, rank, color, login from Cards_in_hand natural join Cards Natural join Card_type where card_id = c8 and Cards_in_hand.username = login;
        
        IF ((SELECT count(DISTINCT id) FROM c_phase WHERE username=login) != 8) THEN          
            drop table c_phase;
            SELECT 'Something wrong with your cards';
        else                      
        
        IF ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1) > 12) THEN 
            SELECT 'Error', 'Combination starts with card from 1 to 12, not jocker';
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c2) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c1)) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c2) != 13)) THEN
            SELECT 'Error', 'Troubles with second card';
        ELSEIF ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c3) > 12) THEN 
            SELECT 'Error', 'Combination starts with card from 1 to 12, not jocker';
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c4) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c3)) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c4) != 13)) THEN
            SELECT 'Error', 'Troubles with fourth card';
        ELSEIF ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c5) > 12) THEN 
            SELECT 'Error', 'Combination starts with card from 1 to 12, not jocker';
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c6) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c5)) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c6) != 13)) THEN
            SELECT 'Error', 'Troubles with sixth card';
        ELSEIF ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c7) > 12) THEN 
            SELECT 'Error', 'Combination starts with card from 1 to 12, not jocker';
        ELSEIF (((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c8) != (select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c7)) and ((select rank from Cards_in_hand natural join Cards natural join Card_type where card_id=c8) != 13)) THEN
            SELECT 'Error', 'Troubles with fourth card';
        ELSE
                   SET pt = ((2*(SELECT game_phase from Games WHERE game_id=(select game_id from Players where username=login)))-1);
            UPDATE Players SET points = points+pt WHERE username=login; 
            UPDATE Games SET game_phase = game_phase+1 WHERE game_id=(select game_id from Players where username=login);
            DELETE FROM Turns WHERE current_player=login;
            SELECT 'Game is over' as info, username as players, points as Points FROM Players WHERE game_id=(SELECT game_id FROM Players WHERE username=login ORDER by points asc);
        end if;
        end if;
    END IF;
    
END//