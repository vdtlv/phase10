sign_up, list_of_games не нуждаются в блокировках и транзакциях


DELIMITER //

CREATE PROCEDURE create_game(login VARCHAR(30), pw VARCHAR(20), pl_count INT)
BEGIN
    IF ((SELECT COUNT(*) from Users WHERE username=login and u_password=pw) = 0) THEN
        SELECT "Error", "Wrong password";
    ELSEIF (pl_count < 2 OR pl_count > 6) THEN
        SELECT "Error", "Wrong number of players";
    ELSE
        IF GET_LOCK("host700505_3396_create_game", 2) THEN -- блокировка
        START TRANSACTION;
            UPDATE Users SET activity = CURRENT_TIMESTAMP WHERE username=login and u_password=pw;
            UPDATE Users SET p_count = pl_count WHERE username=login and u_password=pw;
            INSERT INTO Games VALUES(NULL, NULL, 1);
            INSERT INTO Players VALUES(login, 0, NULL, (SELECT game_id FROM Games order by game_id DESC LIMIT 1));
			INSERT INTO Cards (id) SELECT id FROM Card_type LIMIT 108;             
            INSERT INTO Decks(card_id, game_id) SELECT card_id, game_id FROM Cards, Games WHERE game_id=(SELECT game_id FROM Games order by game_id DESC LIMIT 1) order by card_id desc LIMIT 108;             
            INSERT INTO Turns VALUES(login);             
            INSERT INTO Cards_in_hand (card_id, username) SELECT card_id, current_player FROM Turns, Decks where current_player=login and game_id=(SELECT game_id FROM Games order by game_id DESC LIMIT 1) order by RAND() limit 10;             
            SELECT username as players_in_game FROM Players WHERE game_id = (SELECT game_id FROM Games order by game_id DESC LIMIT 1);
        COMMIT;
        DO RELEASE_LOCK("host700505_3396_create_game");
        end if;
    END IF;

END //


DELIMITER //

CREATE PROCEDURE game_connect(login VARCHAR(30), pw VARCHAR(20), game_id_to_connect INT)
BEGIN
    DECLARE cur_p VARCHAR(30);
    DECLARE cnt_p INT;
    IF ((SELECT COUNT(*) from Users WHERE username=login and u_password=pw) = 1) THEN
        IF ((SELECT COUNT(*) FROM Games WHERE game_id=game_id_to_connect) = 1) THEN
            IF GET_LOCK("host700505_3396_game_connect", 2) THEN -- блокировка
                START TRANSACTION;
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
                END IF;
                COMMIT;
            DO RELEASE_LOCK("host700505_3396_game_connect");
            END IF;
            Call game_state(login,pw);
        ELSE 
            SELECT "Error", "Wrong game_id, check list of games";
            
        END IF;
    ELSE 
        SELECT "Error", "Wrong password";
    END IF;

END // 

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
        IF ((SELECT game_phase FROM Games WHERE game_id=(SELECT game_id FROM Players WHERE username=login))=11) THEN
            SELECT 'Game is over' as info, username as players, points as Points FROM Players WHERE game_id=(SELECT game_id FROM Players WHERE username=login ORDER by points asc);
        END IF;  
        IF ((SELECT COUNT(*) from Cards_in_hand WHERE card_id=c AND username=login)=0) THEN
            SELECT "Oops!", "Wrong card id";
        end IF;
        IF GET_LOCK("host700505_3396_p_card", 2) THEN -- блокировка
            START TRANSACTION;
            IF ((SELECT COUNT(*) from Cards_in_hand WHERE username=login) = 11 ) THEN
                UPDATE Games SET card_on_table = c WHERE game_id=c_g;
                DELETE FROM Cards_in_hand WHERE card_id=c AND username=login;
                UPDATE Turns SET current_player = (SELECT next_player FROM Players WHERE username=login) WHERE current_player=login;
                IF ((SELECT rank FROM Cards NATURAL JOIN Card_type WHERE card_id=c)=14) THEN
                    UPDATE Turns SET current_player = (SELECT next_player FROM Players WHERE username=current_player) WHERE current_player=(SELECT next_player FROM Players WHERE username=login);
                END IF;
            end if;
            if ((SELECT COUNT(*) from Cards_in_hand WHERE username=login) = 10 ) then
                UPDATE Games SET card_on_table = c WHERE game_id=c_g;
                DELETE FROM Cards_in_hand WHERE card_id=c;
            end if;
            COMMIT;
            DO RELEASE_LOCK("host700505_3396_p_card");
        end if;
        if ((SELECT COUNT(*) from Cards_in_hand WHERE username=login) = 9 ) THEN
            SELECT "You already did this", "Call t_card to finish your turn";
        END if;
    END IF;

END//


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
    ELSE   
    IF ((SELECT game_phase FROM Games WHERE game_id=(SELECT game_id FROM Players WHERE username=login))=11) THEN
                SELECT 'Game is over' as info, username as players, points as Points FROM Players WHERE game_id=(SELECT game_id FROM Players WHERE username=login ORDER by points asc);
            END IF;  
    
    IF ((SELECT COUNT(card_id) FROM Cards_in_hand WHERE username=login) = 11) THEN 
        SELECT "You can't take more cards", "Call p_card to finish your turn";
    end IF;
    IF GET_LOCK("host700505_3396_p_card", 2) THEN -- блокировка
        START TRANSACTION;
        IF (c='deck') THEN
            IF ((SELECT COUNT(card_id) FROM Cards_in_hand WHERE username=login) = 10 ) THEN
                INSERT INTO Cards_in_hand (card_id, username) SELECT card_id, login FROM Decks where game_id=c_g and card_id  NOT IN (SELECT card_id FROM Cards_in_hand where game_id=c_g) and card_id!=(select card_on_table from Games where game_id=c_g) order by RAND() limit 1;             ELSEIF ((SELECT COUNT(card_id) FROM Cards_in_hand WHERE username=login) = 9) THEN                     INSERT INTO Cards_in_hand (card_id, username) SELECT card_id, login FROM Decks where game_id=c_g and card_id  NOT IN(SELECT card_id FROM Cards_in_hand where game_id=c_g) and card_id!=(select card_on_table from Games where game_id=c_g) order by RAND() limit 1;
                UPDATE Turns SET current_player = (SELECT next_player FROM Players WHERE username=login) WHERE current_player=login;
                IF ((SELECT rank FROM Games, Cards NATURAL JOIN Card_type WHERE game_id=(SELECT game_id FROM Players WHERE username=login) and card_on_table=card_id)=14) THEN
                    UPDATE Turns SET current_player = (SELECT next_player FROM Players WHERE username=current_player) WHERE current_player=(SELECT next_player FROM Players WHERE username=login);
                END IF;
            END if;
        ELSEIF (c='table') THEN
            IF ((SELECT rank FROM Games, Cards NATURAL JOIN Card_type WHERE game_id=(SELECT game_id FROM Players WHERE username=login) and card_on_table=card_id)=14) THEN
                SELECT "Sorry", "You can take card from deck(1)"; 
            ELSEIF ((SELECT COUNT(card_id) FROM Cards_in_hand WHERE username=login) = 10 ) THEN
                INSERT INTO Cards_in_hand (card_id, username) select card_on_table, login from Games where game_id=c_g;
            ELSEIF ((SELECT COUNT(card_id) FROM Cards_in_hand WHERE username=login) = 9) THEN
                SELECT "Sorry", "You can take card from deck(1)";       
            END IF; 
        ELSE
            SELECT "Sorry", "Select deck(1) or table(2)";
        END IF;
        COMMIT;
        DO RELEASE_LOCK("host700505_3396_p_card");
    end if;
    END IF;

END // 


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

            IF GET_LOCK("host700505_3396_phase1", 2) THEN -- блокировка
                START TRANSACTION;
                    SET pt = ((2*(SELECT game_phase from Games WHERE game_id=(select game_id from Players where username=login)))-1);
                    UPDATE Players SET points = points+pt WHERE username=login;
                    if ((select count(*) from Cards_in_hand where username=login) = 11) THEN
                       UPDATE Games SET card_on_table = (SELECT distinct Decks.card_id FROM Decks, Cards_in_hand where game_id=(select game_id from Players where username=login) and Decks.card_id  NOT IN(SELECT card_id FROM Cards_in_hand where game_id=(select game_id from Players where username=login))  order by RAND() limit 1) WHERE (game_id=(select game_id from Players where username=login)); -- todo
                    end if;
                    UPDATE Games SET game_phase=game_phase+1 WHERE game_id=(select game_id from Players where username=login);
                    SET pl = (SELECT count(*) FROM Players WHERE game_id=(select game_id from Players where username=login))*10;
                    INSERT INTO Card1(cid) SELECT card_id FROM Decks WHERE game_id=(select game_id from Players where username=login) ORDER by rand() limit 10;         
                    INSERT into Card2(cidx, un) SELECT cid, username FROM Card1 cross join Players WHERE game_id=(select game_id from Players where username=login);                    
                    INSERT INTO Card3(cid) SELECT card_id FROM Decks WHERE game_id=(select game_id from Players where username=login) and card_id!=(SELECT card_on_table from Games WHERE game_id=(SELECT game_id FROM Players WHERE username=login)) ORDER by rand() limit pl;         
                    DELETE FROM Cards_in_hand WHERE EXISTS (SELECT username FROM Players WHERE game_id= (SELECT game_id FROM Players WHERE username=login));        
                    INSERT INTO Cards_in_hand (card_id, username) SELECT cid, un FROM Card2 d1 inner join Card3 d2 on d1.id = d2.id;  
                    UPDATE Turns SET current_player = (SELECT next_player FROM Players WHERE username=login) WHERE current_player=login;
                    
                COMMIT;
            DO RELEASE_LOCK("host700505_3396_phase1");
            end if;
            
        end if;
        end if;
        DROP TEMPORARY TABLE IF EXISTS Card1;
        DROP TEMPORARY TABLE IF EXISTS Card2;
        DROP TEMPORARY TABLE IF EXISTS Card3;
        SELECT 'You get points!';
    END IF;
    

END// 

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
             IF GET_LOCK("host700505_3396_phase2", 2) THEN -- блокировка
                START TRANSACTION;
                    SET pt = ((2*(SELECT game_phase from Games WHERE game_id=(select game_id from Players where username=login)))-1);
                    UPDATE Players SET points = points+pt WHERE username=login;
                    if ((select count(*) from Cards_in_hand where username=login) = 11) THEN
                       UPDATE Games SET card_on_table = (SELECT distinct Decks.card_id FROM Decks, Cards_in_hand where game_id=(select game_id from Players where username=login) and Decks.card_id  NOT IN(SELECT card_id FROM Cards_in_hand where game_id=(select game_id from Players where username=login))  order by RAND() limit 1) WHERE (game_id=(select game_id from Players where username=login)); -- todo
                    end if;
                    UPDATE Games SET game_phase=game_phase+1 WHERE game_id=(select game_id from Players where username=login);
                    SET pl = (SELECT count(*) FROM Players WHERE game_id=(select game_id from Players where username=login))*10;
                    INSERT INTO Card1(cid) SELECT card_id FROM Decks WHERE game_id=(select game_id from Players where username=login) ORDER by rand() limit 10;         
                    INSERT into Card2(cidx, un) SELECT cid, username FROM Card1 cross join Players WHERE game_id=(select game_id from Players where username=login);                    
                    INSERT INTO Card3(cid) SELECT card_id FROM Decks WHERE game_id=(select game_id from Players where username=login) and card_id!=(SELECT card_on_table from Games WHERE game_id=(SELECT game_id FROM Players WHERE username=login)) ORDER by rand() limit pl;         
                    DELETE FROM Cards_in_hand WHERE EXISTS (SELECT username FROM Players WHERE game_id= (SELECT game_id FROM Players WHERE username=login));        
                    INSERT INTO Cards_in_hand (card_id, username) SELECT cid, un FROM Card2 d1 inner join Card3 d2 on d1.id = d2.id;  
                    UPDATE Turns SET current_player = (SELECT next_player FROM Players WHERE username=login) WHERE current_player=login;
                    
                COMMIT;
            DO RELEASE_LOCK("host700505_3396_phase2");
            end if;
            
        end if;
        end if;
        DROP TEMPORARY TABLE IF EXISTS Card1;
        DROP TEMPORARY TABLE IF EXISTS Card2;
        DROP TEMPORARY TABLE IF EXISTS Card3;
        SELECT 'You get points!';
    END IF;
    

END// 


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
            IF GET_LOCK("host700505_3396_phase3", 2) THEN -- блокировка
                START TRANSACTION;
                    SET pt = ((2*(SELECT game_phase from Games WHERE game_id=(select game_id from Players where username=login)))-1);
                    UPDATE Players SET points = points+pt WHERE username=login;
                    if ((select count(*) from Cards_in_hand where username=login) = 11) THEN
                       UPDATE Games SET card_on_table = (SELECT distinct Decks.card_id FROM Decks, Cards_in_hand where game_id=(select game_id from Players where username=login) and Decks.card_id  NOT IN(SELECT card_id FROM Cards_in_hand where game_id=(select game_id from Players where username=login))  order by RAND() limit 1) WHERE (game_id=(select game_id from Players where username=login)); -- todo
                    end if;
                    UPDATE Games SET game_phase=game_phase+1 WHERE game_id=(select game_id from Players where username=login);
                    SET pl = (SELECT count(*) FROM Players WHERE game_id=(select game_id from Players where username=login))*10;
                    INSERT INTO Card1(cid) SELECT card_id FROM Decks WHERE game_id=(select game_id from Players where username=login) ORDER by rand() limit 10;         
                    INSERT into Card2(cidx, un) SELECT cid, username FROM Card1 cross join Players WHERE game_id=(select game_id from Players where username=login);                    
                    INSERT INTO Card3(cid) SELECT card_id FROM Decks WHERE game_id=(select game_id from Players where username=login) and card_id!=(SELECT card_on_table from Games WHERE game_id=(SELECT game_id FROM Players WHERE username=login)) ORDER by rand() limit pl;         
                    DELETE FROM Cards_in_hand WHERE EXISTS (SELECT username FROM Players WHERE game_id= (SELECT game_id FROM Players WHERE username=login));        
                    INSERT INTO Cards_in_hand (card_id, username) SELECT cid, un FROM Card2 d1 inner join Card3 d2 on d1.id = d2.id;  
                    UPDATE Turns SET current_player = (SELECT next_player FROM Players WHERE username=login) WHERE current_player=login;
                    
                COMMIT;
            DO RELEASE_LOCK("host700505_3396_phase3");
            end if;
            
        end if;
        end if;
        DROP TEMPORARY TABLE IF EXISTS Card1;
        DROP TEMPORARY TABLE IF EXISTS Card2;
        DROP TEMPORARY TABLE IF EXISTS Card3;
        SELECT 'You get points!';
    END IF;
    

END// 


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
            IF GET_LOCK("host700505_3396_phase4", 2) THEN -- блокировка
                START TRANSACTION;
                    SET pt = ((2*(SELECT game_phase from Games WHERE game_id=(select game_id from Players where username=login)))-1);
                    UPDATE Players SET points = points+pt WHERE username=login;
                    if ((select count(*) from Cards_in_hand where username=login) = 11) THEN
                       UPDATE Games SET card_on_table = (SELECT distinct Decks.card_id FROM Decks, Cards_in_hand where game_id=(select game_id from Players where username=login) and Decks.card_id  NOT IN(SELECT card_id FROM Cards_in_hand where game_id=(select game_id from Players where username=login))  order by RAND() limit 1) WHERE (game_id=(select game_id from Players where username=login)); -- todo
                    end if;
                    UPDATE Games SET game_phase=game_phase+1 WHERE game_id=(select game_id from Players where username=login);
                    SET pl = (SELECT count(*) FROM Players WHERE game_id=(select game_id from Players where username=login))*10;
                    INSERT INTO Card1(cid) SELECT card_id FROM Decks WHERE game_id=(select game_id from Players where username=login) ORDER by rand() limit 10;         
                    INSERT into Card2(cidx, un) SELECT cid, username FROM Card1 cross join Players WHERE game_id=(select game_id from Players where username=login);                    
                    INSERT INTO Card3(cid) SELECT card_id FROM Decks WHERE game_id=(select game_id from Players where username=login) and card_id!=(SELECT card_on_table from Games WHERE game_id=(SELECT game_id FROM Players WHERE username=login)) ORDER by rand() limit pl;         
                    DELETE FROM Cards_in_hand WHERE EXISTS (SELECT username FROM Players WHERE game_id= (SELECT game_id FROM Players WHERE username=login));        
                    INSERT INTO Cards_in_hand (card_id, username) SELECT cid, un FROM Card2 d1 inner join Card3 d2 on d1.id = d2.id;  
                    UPDATE Turns SET current_player = (SELECT next_player FROM Players WHERE username=login) WHERE current_player=login;
                    
                COMMIT;
            DO RELEASE_LOCK("host700505_3396_phase4");
            end if;
            
        end if;
        end if;
        DROP TEMPORARY TABLE IF EXISTS Card1;
        DROP TEMPORARY TABLE IF EXISTS Card2;
        DROP TEMPORARY TABLE IF EXISTS Card3;
        SELECT 'You get points!';
    END IF;
    

END// 


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
            IF GET_LOCK("host700505_3396_phase5", 2) THEN -- блокировка
                START TRANSACTION;
                    SET pt = ((2*(SELECT game_phase from Games WHERE game_id=(select game_id from Players where username=login)))-1);
                    UPDATE Players SET points = points+pt WHERE username=login;
                    if ((select count(*) from Cards_in_hand where username=login) = 11) THEN
                       UPDATE Games SET card_on_table = (SELECT distinct Decks.card_id FROM Decks, Cards_in_hand where game_id=(select game_id from Players where username=login) and Decks.card_id  NOT IN(SELECT card_id FROM Cards_in_hand where game_id=(select game_id from Players where username=login))  order by RAND() limit 1) WHERE (game_id=(select game_id from Players where username=login)); -- todo
                    end if;
                    UPDATE Games SET game_phase=game_phase+1 WHERE game_id=(select game_id from Players where username=login);
                    SET pl = (SELECT count(*) FROM Players WHERE game_id=(select game_id from Players where username=login))*10;
                    INSERT INTO Card1(cid) SELECT card_id FROM Decks WHERE game_id=(select game_id from Players where username=login) ORDER by rand() limit 10;         
                    INSERT into Card2(cidx, un) SELECT cid, username FROM Card1 cross join Players WHERE game_id=(select game_id from Players where username=login);                    
                    INSERT INTO Card3(cid) SELECT card_id FROM Decks WHERE game_id=(select game_id from Players where username=login) and card_id!=(SELECT card_on_table from Games WHERE game_id=(SELECT game_id FROM Players WHERE username=login)) ORDER by rand() limit pl;         
                    DELETE FROM Cards_in_hand WHERE EXISTS (SELECT username FROM Players WHERE game_id= (SELECT game_id FROM Players WHERE username=login));        
                    INSERT INTO Cards_in_hand (card_id, username) SELECT cid, un FROM Card2 d1 inner join Card3 d2 on d1.id = d2.id;  
                    UPDATE Turns SET current_player = (SELECT next_player FROM Players WHERE username=login) WHERE current_player=login;
                    
                COMMIT;
            DO RELEASE_LOCK("host700505_3396_phase5");
            end if;
            
        end if;
        end if;
        DROP TEMPORARY TABLE IF EXISTS Card1;
        DROP TEMPORARY TABLE IF EXISTS Card2;
        DROP TEMPORARY TABLE IF EXISTS Card3;
        SELECT 'You get points!';
    END IF;
    

END// 

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
            IF GET_LOCK("host700505_3396_phase6", 2) THEN -- блокировка
                START TRANSACTION;
                    SET pt = ((2*(SELECT game_phase from Games WHERE game_id=(select game_id from Players where username=login)))-1);
                    UPDATE Players SET points = points+pt WHERE username=login;
                    if ((select count(*) from Cards_in_hand where username=login) = 11) THEN
                       UPDATE Games SET card_on_table = (SELECT distinct Decks.card_id FROM Decks, Cards_in_hand where game_id=(select game_id from Players where username=login) and Decks.card_id  NOT IN(SELECT card_id FROM Cards_in_hand where game_id=(select game_id from Players where username=login))  order by RAND() limit 1) WHERE (game_id=(select game_id from Players where username=login)); -- todo
                    end if;
                    UPDATE Games SET game_phase=game_phase+1 WHERE game_id=(select game_id from Players where username=login);
                    SET pl = (SELECT count(*) FROM Players WHERE game_id=(select game_id from Players where username=login))*10;
                    INSERT INTO Card1(cid) SELECT card_id FROM Decks WHERE game_id=(select game_id from Players where username=login) ORDER by rand() limit 10;         
                    INSERT into Card2(cidx, un) SELECT cid, username FROM Card1 cross join Players WHERE game_id=(select game_id from Players where username=login);                    
                    INSERT INTO Card3(cid) SELECT card_id FROM Decks WHERE game_id=(select game_id from Players where username=login) and card_id!=(SELECT card_on_table from Games WHERE game_id=(SELECT game_id FROM Players WHERE username=login)) ORDER by rand() limit pl;         
                    DELETE FROM Cards_in_hand WHERE EXISTS (SELECT username FROM Players WHERE game_id= (SELECT game_id FROM Players WHERE username=login));        
                    INSERT INTO Cards_in_hand (card_id, username) SELECT cid, un FROM Card2 d1 inner join Card3 d2 on d1.id = d2.id;  
                    UPDATE Turns SET current_player = (SELECT next_player FROM Players WHERE username=login) WHERE current_player=login;
                    
                COMMIT;
            DO RELEASE_LOCK("host700505_3396_phase6");
            end if;
            
        end if;
        end if;
        DROP TEMPORARY TABLE IF EXISTS Card1;
        DROP TEMPORARY TABLE IF EXISTS Card2;
        DROP TEMPORARY TABLE IF EXISTS Card3;
        SELECT 'You get points!';
    END IF;
    

END// 


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
            IF GET_LOCK("host700505_3396_phase7", 2) THEN -- блокировка
                START TRANSACTION;
                    SET pt = ((2*(SELECT game_phase from Games WHERE game_id=(select game_id from Players where username=login)))-1);
                    UPDATE Players SET points = points+pt WHERE username=login;
                    if ((select count(*) from Cards_in_hand where username=login) = 11) THEN
                       UPDATE Games SET card_on_table = (SELECT distinct Decks.card_id FROM Decks, Cards_in_hand where game_id=(select game_id from Players where username=login) and Decks.card_id  NOT IN(SELECT card_id FROM Cards_in_hand where game_id=(select game_id from Players where username=login))  order by RAND() limit 1) WHERE (game_id=(select game_id from Players where username=login)); -- todo
                    end if;
                    UPDATE Games SET game_phase=game_phase+1 WHERE game_id=(select game_id from Players where username=login);
                    SET pl = (SELECT count(*) FROM Players WHERE game_id=(select game_id from Players where username=login))*10;
                    INSERT INTO Card1(cid) SELECT card_id FROM Decks WHERE game_id=(select game_id from Players where username=login) ORDER by rand() limit 10;         
                    INSERT into Card2(cidx, un) SELECT cid, username FROM Card1 cross join Players WHERE game_id=(select game_id from Players where username=login);                    
                    INSERT INTO Card3(cid) SELECT card_id FROM Decks WHERE game_id=(select game_id from Players where username=login) and card_id!=(SELECT card_on_table from Games WHERE game_id=(SELECT game_id FROM Players WHERE username=login)) ORDER by rand() limit pl;         
                    DELETE FROM Cards_in_hand WHERE EXISTS (SELECT username FROM Players WHERE game_id= (SELECT game_id FROM Players WHERE username=login));        
                    INSERT INTO Cards_in_hand (card_id, username) SELECT cid, un FROM Card2 d1 inner join Card3 d2 on d1.id = d2.id;  
                    UPDATE Turns SET current_player = (SELECT next_player FROM Players WHERE username=login) WHERE current_player=login;
                    
                COMMIT;
            DO RELEASE_LOCK("host700505_3396_phase7");
            end if;
            
        end if;
        end if;
        DROP TEMPORARY TABLE IF EXISTS Card1;
        DROP TEMPORARY TABLE IF EXISTS Card2;
        DROP TEMPORARY TABLE IF EXISTS Card3;
        SELECT 'You get points!';
    END IF;
    

END// 

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
            IF GET_LOCK("host700505_3396_phase8", 2) THEN -- блокировка
                START TRANSACTION;
                    SET pt = ((2*(SELECT game_phase from Games WHERE game_id=(select game_id from Players where username=login)))-1);
                    UPDATE Players SET points = points+pt WHERE username=login;
                    if ((select count(*) from Cards_in_hand where username=login) = 11) THEN
                       UPDATE Games SET card_on_table = (SELECT distinct Decks.card_id FROM Decks, Cards_in_hand where game_id=(select game_id from Players where username=login) and Decks.card_id  NOT IN(SELECT card_id FROM Cards_in_hand where game_id=(select game_id from Players where username=login))  order by RAND() limit 1) WHERE (game_id=(select game_id from Players where username=login)); -- todo
                    end if;
                    UPDATE Games SET game_phase=game_phase+1 WHERE game_id=(select game_id from Players where username=login);
                    SET pl = (SELECT count(*) FROM Players WHERE game_id=(select game_id from Players where username=login))*10;
                    INSERT INTO Card1(cid) SELECT card_id FROM Decks WHERE game_id=(select game_id from Players where username=login) ORDER by rand() limit 10;         
                    INSERT into Card2(cidx, un) SELECT cid, username FROM Card1 cross join Players WHERE game_id=(select game_id from Players where username=login);                    
                    INSERT INTO Card3(cid) SELECT card_id FROM Decks WHERE game_id=(select game_id from Players where username=login) and card_id!=(SELECT card_on_table from Games WHERE game_id=(SELECT game_id FROM Players WHERE username=login)) ORDER by rand() limit pl;         
                    DELETE FROM Cards_in_hand WHERE EXISTS (SELECT username FROM Players WHERE game_id= (SELECT game_id FROM Players WHERE username=login));        
                    INSERT INTO Cards_in_hand (card_id, username) SELECT cid, un FROM Card2 d1 inner join Card3 d2 on d1.id = d2.id;  
                    UPDATE Turns SET current_player = (SELECT next_player FROM Players WHERE username=login) WHERE current_player=login;
                    
                COMMIT;
            DO RELEASE_LOCK("host700505_3396_phase8");
            end if;
            
        end if;
        end if;
        DROP TEMPORARY TABLE IF EXISTS Card1;
        DROP TEMPORARY TABLE IF EXISTS Card2;
        DROP TEMPORARY TABLE IF EXISTS Card3;
        SELECT 'You get points!';
    END IF;
    

END// 



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
            IF GET_LOCK("host700505_3396_phase9", 2) THEN -- блокировка
                START TRANSACTION;
                    SET pt = ((2*(SELECT game_phase from Games WHERE game_id=(select game_id from Players where username=login)))-1);
                    UPDATE Players SET points = points+pt WHERE username=login;
                    if ((select count(*) from Cards_in_hand where username=login) = 11) THEN
                       UPDATE Games SET card_on_table = (SELECT distinct Decks.card_id FROM Decks, Cards_in_hand where game_id=(select game_id from Players where username=login) and Decks.card_id  NOT IN(SELECT card_id FROM Cards_in_hand where game_id=(select game_id from Players where username=login))  order by RAND() limit 1) WHERE (game_id=(select game_id from Players where username=login)); -- todo
                    end if;
                    UPDATE Games SET game_phase=game_phase+1 WHERE game_id=(select game_id from Players where username=login);
                    SET pl = (SELECT count(*) FROM Players WHERE game_id=(select game_id from Players where username=login))*10;
                    INSERT INTO Card1(cid) SELECT card_id FROM Decks WHERE game_id=(select game_id from Players where username=login) ORDER by rand() limit 10;         
                    INSERT into Card2(cidx, un) SELECT cid, username FROM Card1 cross join Players WHERE game_id=(select game_id from Players where username=login);                    
                    INSERT INTO Card3(cid) SELECT card_id FROM Decks WHERE game_id=(select game_id from Players where username=login) and card_id!=(SELECT card_on_table from Games WHERE game_id=(SELECT game_id FROM Players WHERE username=login)) ORDER by rand() limit pl;         
                    DELETE FROM Cards_in_hand WHERE EXISTS (SELECT username FROM Players WHERE game_id= (SELECT game_id FROM Players WHERE username=login));        
                    INSERT INTO Cards_in_hand (card_id, username) SELECT cid, un FROM Card2 d1 inner join Card3 d2 on d1.id = d2.id;  
                    UPDATE Turns SET current_player = (SELECT next_player FROM Players WHERE username=login) WHERE current_player=login;
                    
                COMMIT;
            DO RELEASE_LOCK("host700505_3396_phase9");
            end if;
            
        end if;
        end if;
        DROP TEMPORARY TABLE IF EXISTS Card1;
        DROP TEMPORARY TABLE IF EXISTS Card2;
        DROP TEMPORARY TABLE IF EXISTS Card3;
        SELECT 'You get points!';
    END IF;
    

END// 


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
            IF GET_LOCK("host700505_3396_phase10", 2) THEN -- блокировка
                START TRANSACTION;
                SET pt = ((2*(SELECT game_phase from Games WHERE game_id=(select game_id from Players where username=login)))-1);
                UPDATE Players SET points = points+pt WHERE username=login;
                UPDATE Games SET game_phase = game_phase+1 WHERE game_id=(select game_id from Players where username=login);
                DELETE FROM Turns WHERE current_player=login;
                COMMIT;
            DO RELEASE_LOCK("host700505_3396_phase10");
            end if;
            
        end if;
        end if;
        DROP TEMPORARY TABLE IF EXISTS Card1;
        DROP TEMPORARY TABLE IF EXISTS Card2;
        DROP TEMPORARY TABLE IF EXISTS Card3;
        SELECT 'Game is over' as info, username as players, points as Points FROM Players WHERE game_id=(SELECT game_id FROM Players WHERE username=login ORDER by points asc);
    END IF;
    

END// 
            




