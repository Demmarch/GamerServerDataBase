use [KURS]
GO

-- Добавление привилегий, статусов администрации сервера, системный доступ к серверу и услуги
INSERT INTO PrivilegeAndServices (Name, Type, Description)
VALUES
('System', 'System', 'System server access'), -- для себя: /sys <password> - вход в системный доступ /startserver /shuttdown - "отрубить" сервер /setstaff <player> (не забыть)
('Unban', 'Service', 'Разбан || 100'),
('Unmute', 'Service', 'Размут || 50'),
('ADMINISTRATOR', 'Stuff', '/fly, /gm 0, /gm 1, /gm 2, /gm 3, /kick, /tempban, /tempmute, /ban, /mute, /unban, /unmute, /list, /list bans, /list mutes, /givedonate, PROTECTED'),
('DEV', 'Stuff', '/fly, /gm 0, /gm 1, /gm 2, /gm 3, /kick, /tempban, /tempmute, /ban, /mute, /unban, /unmute, /givedonate, PROTECTED'),
('Helper', 'Stuff', '/fly, /gm 0, /gm 1, /gm 2, /gm 3, /kick, /tempban, /tempmute, /ban, /mute, /unban, /unmute, /reports'),
('Moderator', 'Stuff', '/fly, /gm 0, /gm 1, /gm 2, /gm 3, /kick, /tempban, /tempmute, /ban, /mute, /unban, /unmute, /reports, /list, /list all, /list bans, /list mutes'),
('Player', 'Player', 'Обычный игрок'),
('VIP', 'Privilege', '/fly || 30'),
('Premium', 'Privilege', '/fly, /gm 0, gm 1 || 60'),
('Lord', 'Privilege', '/fly, /gm 0, gm 1, /gm 3 || 120'),
('Основатель', 'Privilege', '/fly, /gm 0, gm 1, /gm 3, /kick || 220'),
('Admin', 'Privilege', '/fly, /gm 0, gm 1, /gm 3, /kick, /tempmute, /mute || 400'),
('GL Admin', 'Privilege', '/fly, /gm 0, gm 1, /gm 3, /kick, /tempmute, /mute, /tempban, /ban || 799');
GO

-- Добавим игроков, стафф и донатеров
INSERT INTO Players (Nickname, PasswordHash, RegistrationDate, ActivePrivilegeID, isBanned, isMuted)
VALUES
('System', HASHBYTES('SHA2_256', CAST('!?REALSTRONGPASSWORD!?' AS VARCHAR(MAX))), '2024-01-01', (SELECT PrSrID FROM PrivilegeAndServices WHERE Name = 'System'), 0, 0),
('Demmarc', HASHBYTES('SHA2_256', CAST('!?SRTORNGpassword' AS VARCHAR(MAX))), '2024-02-15', (SELECT PrSrID FROM PrivilegeAndServices WHERE Name = 'ADMINISTRATOR'), 0, 0),
('Player123', HASHBYTES('SHA2_256', CAST('player123' AS VARCHAR(MAX))), '2024-03-10', (SELECT PrSrID FROM PrivilegeAndServices WHERE Name = 'Player'), 0, 0),
('ShadowGamer', HASHBYTES('SHA2_256', CAST('dom123' AS VARCHAR(MAX))), '2024-04-01', (SELECT PrSrID FROM PrivilegeAndServices WHERE Name = 'Player'), 0, 0),
('MysticBlade', HASHBYTES('SHA2_256', CAST('azdfg456' AS VARCHAR(MAX))), '2024-04-05', (SELECT PrSrID FROM PrivilegeAndServices WHERE Name = 'VIP'), 0, 0),
('ZeroCool', HASHBYTES('SHA2_256', CAST('GHBff123' AS VARCHAR(MAX))), '2024-04-10', (SELECT PrSrID FROM PrivilegeAndServices WHERE Name = 'Player'), 1, 0),
('ChattyKathy', HASHBYTES('SHA2_256', CAST('FRed1234' AS VARCHAR(MAX))), '2024-04-12', (SELECT PrSrID FROM PrivilegeAndServices WHERE Name = 'Player'), 0, 1),
('Artem336', HASHBYTES('SHA2_256', CAST('asdfg' AS VARCHAR(MAX))), '2024-04-02', (SELECT PrSrID FROM PrivilegeAndServices WHERE Name = 'Premium'), 0, 0),
('Forum', HASHBYTES('SHA2_256', CAST('Q!wE3Rty' AS VARCHAR(MAX))), '2024-04-05', (SELECT PrSrID FROM PrivilegeAndServices WHERE Name = 'VIP'), 0, 0),
('A22', HASHBYTES('SHA2_256', CAST('GLADMIN' AS VARCHAR(MAX))), '2024-04-10', (SELECT PrSrID FROM PrivilegeAndServices WHERE Name = 'GL Admin'), 1, 0),
('Qwerty_Asdfg', HASHBYTES('SHA2_256', CAST('1234qwerty' AS VARCHAR(MAX))), '2024-04-12', (SELECT PrSrID FROM PrivilegeAndServices WHERE Name = 'Player'), 0, 1);
GO


