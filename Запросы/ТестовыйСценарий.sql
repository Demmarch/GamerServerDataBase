USE [KURS]
GO

-- Включаем вывод сообщений PRINT для отслеживания выполнения процедур
SET NOCOUNT OFF;

PRINT '--- НАЧАЛО ТЕСТОВОГО СЦЕНАРИЯ ---';
GO

-- --- 0. Объявление ГЛОБАЛЬНЫХ переменных для теста (если нужны между GO блоками) ---
DECLARE @TestPlayerNickname_Global NVARCHAR(100) = 'TestUser_Scenario';
DECLARE @TestPlayerPassword_Global NVARCHAR(100) = 'TestPassword123';
DECLARE @InitialModeratorNickname_Global NVARCHAR(100) = 'Demmarc';
DECLARE @InitialSystemNickname_Global NVARCHAR(100) = 'System';

DECLARE @GlobalTestPlayerID INT; 
DECLARE @GlobalModeratorID INT;
DECLARE @GlobalSystemPlayerID INT;

DECLARE @UnmuteServiceID_Global INT, @UnmuteServicePrice_Global MONEY;
DECLARE @UnbanServiceID_Global INT, @UnbanServicePrice_Global MONEY;
DECLARE @VipPrivilegeID_Global INT, @VipPrivilegePrice_Global MONEY;
DECLARE @PremiumPrivilegeID_Global INT;

PRINT '--- 0. Инициализация глобальных переменных и ID ---';

SELECT @GlobalModeratorID = PlayerID FROM Players WHERE Nickname = @InitialModeratorNickname_Global;
IF @GlobalModeratorID IS NULL
BEGIN
    PRINT 'Критическая ошибка: Модератор "' + @InitialModeratorNickname_Global + '" не найден. Попытка использовать "System".';
    SELECT @GlobalModeratorID = PlayerID FROM Players WHERE Nickname = @InitialSystemNickname_Global;
    IF @GlobalModeratorID IS NULL
    BEGIN
        PRINT 'Критическая ошибка: Игрок "' + @InitialSystemNickname_Global + '" также не найден.';
        RETURN;
    END
    PRINT 'Предупреждение: Модератор "' + @InitialModeratorNickname_Global + '" не найден, используется "' + @InitialSystemNickname_Global + '" в качестве модератора.';
END

SELECT @GlobalSystemPlayerID = PlayerID FROM Players WHERE Nickname = @InitialSystemNickname_Global;
IF @GlobalSystemPlayerID IS NULL
BEGIN
    PRINT 'Критическая ошибка: Игрок "' + @InitialSystemNickname_Global + '" не найден. Он необходим для работы некоторых процедур.';
    RETURN;
END

SELECT @UnmuteServiceID_Global = PrSrID, @UnmuteServicePrice_Global = dbo.GetPriceFromDescription(Description)
FROM PrivilegeAndServices WHERE Name = 'Unmute';
SELECT @UnbanServiceID_Global = PrSrID, @UnbanServicePrice_Global = dbo.GetPriceFromDescription(Description)
FROM PrivilegeAndServices WHERE Name = 'Unban';
SELECT @VipPrivilegeID_Global = PrSrID, @VipPrivilegePrice_Global = dbo.GetPriceFromDescription(Description)
FROM PrivilegeAndServices WHERE Name = 'VIP';
SELECT @PremiumPrivilegeID_Global = PrSrID
FROM PrivilegeAndServices WHERE Name = 'Premium';

IF @UnmuteServiceID_Global IS NULL OR @UnbanServiceID_Global IS NULL OR @VipPrivilegeID_Global IS NULL OR @PremiumPrivilegeID_Global IS NULL
BEGIN
    PRINT 'Критическая ошибка: Одна или несколько услуг/привилегий (Unmute, Unban, VIP, Premium) не найдены или для них не указана цена.';
    RETURN;
END

PRINT 'Глобальные переменные инициализированы. ModeratorID: ' + ISNULL(CAST(@GlobalModeratorID AS VARCHAR), 'NULL') +
      ', SystemPlayerID: ' + ISNULL(CAST(@GlobalSystemPlayerID AS VARCHAR), 'NULL') +
      ', UnmuteServiceID: ' + ISNULL(CAST(@UnmuteServiceID_Global AS VARCHAR), 'NULL') + ' (Цена: ' + ISNULL(CAST(@UnmuteServicePrice_Global AS VARCHAR), 'N/A') + ')' +
      ', UnbanServiceID: ' + ISNULL(CAST(@UnbanServiceID_Global AS VARCHAR), 'NULL') + ' (Цена: ' + ISNULL(CAST(@UnbanServicePrice_Global AS VARCHAR), 'N/A') + ')' +
      ', VipPrivilegeID: ' + ISNULL(CAST(@VipPrivilegeID_Global AS VARCHAR), 'NULL') + ' (Цена: ' + ISNULL(CAST(@VipPrivilegePrice_Global AS VARCHAR), 'N/A') + ')' +
      ', PremiumPrivilegeID: ' + ISNULL(CAST(@PremiumPrivilegeID_Global AS VARCHAR), 'NULL');
GO

-- --- 1. Регистрация нового игрока ---
PRINT '';
PRINT '--- 1. Регистрация нового игрока: TestUser_Scenario ---';
DECLARE @TestPlayerNickname_S1 NVARCHAR(100) = 'TestUser_Scenario';
DECLARE @TestPlayerPassword_S1 NVARCHAR(100) = 'TestPassword123';
DECLARE @RegisteredPlayerID_S1 INT;

IF EXISTS (SELECT 1 FROM Players WHERE Nickname = @TestPlayerNickname_S1)
BEGIN
    PRINT 'Обнаружен игрок ' + @TestPlayerNickname_S1 + ' от предыдущих тестов. Удаление...';
    DECLARE @PlayerToDeleteID_S1 INT;
    SELECT @PlayerToDeleteID_S1 = PlayerID FROM Players WHERE Nickname = @TestPlayerNickname_S1;

    DELETE FROM HistoryDonations WHERE PlayerID = @PlayerToDeleteID_S1;
    DELETE FROM Unbans WHERE BanID IN (SELECT BanID FROM Bans WHERE PlayerID = @PlayerToDeleteID_S1);
    DELETE FROM Bans WHERE PlayerID = @PlayerToDeleteID_S1;
    DELETE FROM UnMutes WHERE MuteID IN (SELECT MuteID FROM Mute WHERE PlayerID = @PlayerToDeleteID_S1);
    DELETE FROM Mute WHERE PlayerID = @PlayerToDeleteID_S1;
    DELETE FROM Players WHERE PlayerID = @PlayerToDeleteID_S1;
    PRINT 'Игрок ' + @TestPlayerNickname_S1 + ' удален.';
END

EXEC RegisterPlayer @Nickname = @TestPlayerNickname_S1, @PasswordInput = @TestPlayerPassword_S1;
SELECT @RegisteredPlayerID_S1 = PlayerID FROM Players WHERE Nickname = @TestPlayerNickname_S1;
PRINT 'ID нового игрока ' + @TestPlayerNickname_S1 + ': ' + ISNULL(CAST(@RegisteredPlayerID_S1 AS VARCHAR(10)), 'НЕ НАЙДЕН');

SELECT PlayerID, Nickname, RegistrationDate, ActivePrivilegeID, isBanned, isMuted
FROM Players WHERE Nickname = @TestPlayerNickname_S1;
GO

-- --- 2. Мут этого игрока ---
PRINT '';
DECLARE @TestPlayerID_S2 INT, @ModeratorID_S2 INT, @PlayerNickname_S2 NVARCHAR(100);
DECLARE @CalculatedMuteEndDate_S2 DATE; -- Переменная для результата DATEADD

SELECT @TestPlayerID_S2 = PlayerID, @PlayerNickname_S2 = Nickname FROM Players WHERE Nickname = 'TestUser_Scenario';
SELECT @ModeratorID_S2 = PlayerID FROM Players WHERE Nickname = 'Demmarc'; 
IF @ModeratorID_S2 IS NULL SELECT @ModeratorID_S2 = PlayerID FROM Players WHERE Nickname = 'System';

PRINT '--- 2. Мут игрока ' + ISNULL(@PlayerNickname_S2, 'N/A') + ' (ID: ' + ISNULL(CAST(@TestPlayerID_S2 AS VARCHAR), 'N/A') + ') модератором ID ' + ISNULL(CAST(@ModeratorID_S2 AS VARCHAR), 'N/A') + ' ---';

IF @TestPlayerID_S2 IS NOT NULL AND @ModeratorID_S2 IS NOT NULL
BEGIN
    SET @CalculatedMuteEndDate_S2 = DATEADD(day, 7, GETDATE()); -- Вычисляем дату заранее

    EXEC MutePlayer @PlayerID = @TestPlayerID_S2,
                     @ModeratorID = @ModeratorID_S2,
                     @Reason = 'Тестовый мут за флуд',
                     @MuteEndDate = @CalculatedMuteEndDate_S2, -- Используем переменную
                     @isPermanentMute = 0;

    SELECT p.Nickname, p.isMuted, m.Reason, m.StartDate, m.EndDate, m.isPermanent AS MuteIsPermanent
    FROM Players p
    LEFT JOIN Mute m ON p.PlayerID = m.PlayerID AND m.MuteID = (SELECT TOP 1 MuteID FROM Mute subM WHERE subM.PlayerID = p.PlayerID ORDER BY subM.StartDate DESC) 
    WHERE p.PlayerID = @TestPlayerID_S2;
    SELECT * FROM CurrentlyMutedPlayers WHERE PlayerID = @TestPlayerID_S2;
END
ELSE
BEGIN
    PRINT 'Ошибка: Не удалось получить ID игрока или модератора для мута.';
END
GO

-- --- 3. Игрок покупает размут ---
PRINT '';
DECLARE @TestPlayerID_S3 INT, @PlayerNickname_S3 NVARCHAR(100);
DECLARE @UnmuteServiceID_S3 INT, @UnmuteServicePrice_S3 MONEY;
SELECT @TestPlayerID_S3 = PlayerID, @PlayerNickname_S3 = Nickname FROM Players WHERE Nickname = 'TestUser_Scenario';
SELECT @UnmuteServiceID_S3 = PrSrID, @UnmuteServicePrice_S3 = dbo.GetPriceFromDescription(Description)
FROM PrivilegeAndServices WHERE Name = 'Unmute';

PRINT '--- 3. Игрок ' + ISNULL(@PlayerNickname_S3, 'N/A') + ' (ID: ' + ISNULL(CAST(@TestPlayerID_S3 AS VARCHAR), 'N/A') + ') покупает размут ---';

IF @TestPlayerID_S3 IS NOT NULL AND @UnmuteServiceID_S3 IS NOT NULL AND @UnmuteServicePrice_S3 IS NOT NULL
BEGIN
    EXEC PurchaseDonation @PlayerID = @TestPlayerID_S3,
                             @PrSrID = @UnmuteServiceID_S3,
                             @PaymentAmount = @UnmuteServicePrice_S3;

    SELECT p.Nickname, p.isMuted, ps.Name AS PurchasedItem, hd.PaymentDate, hd.Amount
    FROM Players p
    LEFT JOIN HistoryDonations hd ON p.PlayerID = hd.PlayerID AND hd.PrSrID = @UnmuteServiceID_S3 AND hd.PaymentDate >= DATEADD(minute, -5, GETDATE()) 
    LEFT JOIN PrivilegeAndServices ps ON hd.PrSrID = ps.PrSrID
    WHERE p.PlayerID = @TestPlayerID_S3;
    SELECT * FROM CurrentlyMutedPlayers WHERE PlayerID = @TestPlayerID_S3;
END
ELSE
BEGIN
    PRINT 'Ошибка: Не удалось получить ID игрока, ID услуги размута или цену.';
END
GO

-- --- 4. Игрока банят ---
PRINT '';
DECLARE @TestPlayerID_S4 INT, @ModeratorID_S4 INT, @PlayerNickname_S4 NVARCHAR(100);
DECLARE @CalculatedBanEndDate_S4 DATE; -- Переменная для результата DATEADD

SELECT @TestPlayerID_S4 = PlayerID, @PlayerNickname_S4 = Nickname FROM Players WHERE Nickname = 'TestUser_Scenario';
SELECT @ModeratorID_S4 = PlayerID FROM Players WHERE Nickname = 'Demmarc';
IF @ModeratorID_S4 IS NULL SELECT @ModeratorID_S4 = PlayerID FROM Players WHERE Nickname = 'System';

PRINT '--- 4. Бан игрока ' + ISNULL(@PlayerNickname_S4, 'N/A') + ' (ID: ' + ISNULL(CAST(@TestPlayerID_S4 AS VARCHAR), 'N/A') + ') модератором ID ' + ISNULL(CAST(@ModeratorID_S4 AS VARCHAR), 'N/A') + ' ---';

IF @TestPlayerID_S4 IS NOT NULL AND @ModeratorID_S4 IS NOT NULL
BEGIN
    SET @CalculatedBanEndDate_S4 = DATEADD(month, 1, GETDATE()); -- Вычисляем дату заранее

    EXEC BanPlayer @PlayerID = @TestPlayerID_S4,
                    @ModeratorID = @ModeratorID_S4,
                    @Reason = 'Тестовый бан за читы',
                    @BanEndDate = @CalculatedBanEndDate_S4, -- Используем переменную
                    @isPermanentBan = 0;

    SELECT p.Nickname, p.isBanned, b.Reason, b.StartDate, b.EndDate, b.isPermanent AS BanIsPermanent
    FROM Players p
    LEFT JOIN Bans b ON p.PlayerID = b.PlayerID AND b.BanID = (SELECT TOP 1 BanID FROM Bans subB WHERE subB.PlayerID = p.PlayerID ORDER BY subB.StartDate DESC) 
    WHERE p.PlayerID = @TestPlayerID_S4;
    SELECT * FROM CurrentlyBannedPlayers WHERE PlayerID = @TestPlayerID_S4;
END
ELSE
BEGIN
    PRINT 'Ошибка: Не удалось получить ID игрока или модератора для бана.';
END
GO

-- --- 5. Игрок покупает разбан ---
PRINT '';
DECLARE @TestPlayerID_S5 INT, @PlayerNickname_S5 NVARCHAR(100);
DECLARE @UnbanServiceID_S5 INT, @UnbanServicePrice_S5 MONEY;
SELECT @TestPlayerID_S5 = PlayerID, @PlayerNickname_S5 = Nickname FROM Players WHERE Nickname = 'TestUser_Scenario';
SELECT @UnbanServiceID_S5 = PrSrID, @UnbanServicePrice_S5 = dbo.GetPriceFromDescription(Description)
FROM PrivilegeAndServices WHERE Name = 'Unban';

PRINT '--- 5. Игрок ' + ISNULL(@PlayerNickname_S5, 'N/A') + ' (ID: ' + ISNULL(CAST(@TestPlayerID_S5 AS VARCHAR), 'N/A') + ') покупает разбан ---';

IF @TestPlayerID_S5 IS NOT NULL AND @UnbanServiceID_S5 IS NOT NULL AND @UnbanServicePrice_S5 IS NOT NULL
BEGIN
    EXEC PurchaseDonation @PlayerID = @TestPlayerID_S5,
                             @PrSrID = @UnbanServiceID_S5,
                             @PaymentAmount = @UnbanServicePrice_S5;

    SELECT p.Nickname, p.isBanned, ps.Name AS PurchasedItem, hd.PaymentDate, hd.Amount
    FROM Players p
    LEFT JOIN HistoryDonations hd ON p.PlayerID = hd.PlayerID AND hd.PrSrID = @UnbanServiceID_S5 AND hd.PaymentDate >= DATEADD(minute, -5, GETDATE())
    LEFT JOIN PrivilegeAndServices ps ON hd.PrSrID = ps.PrSrID
    WHERE p.PlayerID = @TestPlayerID_S5;
    SELECT * FROM CurrentlyBannedPlayers WHERE PlayerID = @TestPlayerID_S5;
END
ELSE
BEGIN
    PRINT 'Ошибка: Не удалось получить ID игрока, ID услуги разбана или цену.';
END
GO

-- --- 6. Игрок покупает привилегию (например, VIP) ---
PRINT '';
DECLARE @TestPlayerID_S6 INT, @PlayerNickname_S6 NVARCHAR(100);
DECLARE @VipPrivilegeID_S6 INT, @VipPrivilegePrice_S6 MONEY;
SELECT @TestPlayerID_S6 = PlayerID, @PlayerNickname_S6 = Nickname FROM Players WHERE Nickname = 'TestUser_Scenario';
SELECT @VipPrivilegeID_S6 = PrSrID, @VipPrivilegePrice_S6 = dbo.GetPriceFromDescription(Description)
FROM PrivilegeAndServices WHERE Name = 'VIP';

PRINT '--- 6. Игрок ' + ISNULL(@PlayerNickname_S6, 'N/A') + ' (ID: ' + ISNULL(CAST(@TestPlayerID_S6 AS VARCHAR), 'N/A') + ') покупает привилегию VIP ---';

IF @TestPlayerID_S6 IS NOT NULL AND @VipPrivilegeID_S6 IS NOT NULL AND @VipPrivilegePrice_S6 IS NOT NULL
BEGIN
    EXEC PurchaseDonation @PlayerID = @TestPlayerID_S6,
                             @PrSrID = @VipPrivilegeID_S6,
                             @PaymentAmount = @VipPrivilegePrice_S6;

    SELECT p.Nickname, ps_active.Name AS CurrentPrivilege, ps_purch.Name AS PurchasedItem, hd.PaymentDate, hd.Amount
    FROM Players p
    LEFT JOIN PrivilegeAndServices ps_active ON p.ActivePrivilegeID = ps_active.PrSrID
    LEFT JOIN HistoryDonations hd ON p.PlayerID = hd.PlayerID AND hd.PrSrID = @VipPrivilegeID_S6 AND hd.PaymentDate >= DATEADD(minute, -5, GETDATE())
    LEFT JOIN PrivilegeAndServices ps_purch ON hd.PrSrID = ps_purch.PrSrID
    WHERE p.PlayerID = @TestPlayerID_S6;
END
ELSE
BEGIN
    PRINT 'Ошибка: Не удалось получить ID игрока, ID привилегии VIP или цену.';
END
GO

-- --- 7. Игроку дают донат выше, чем у него есть (например, Premium) ---
PRINT '';
DECLARE @TestPlayerID_S7 INT, @ModeratorID_S7 INT, @PremiumPrivilegeID_S7 INT;
DECLARE @PlayerNickname_S7 NVARCHAR(100), @ModeratorNickname_S7 NVARCHAR(100);

SELECT @TestPlayerID_S7 = PlayerID, @PlayerNickname_S7 = Nickname FROM Players WHERE Nickname = 'TestUser_Scenario';
SELECT @ModeratorID_S7 = PlayerID, @ModeratorNickname_S7 = Nickname FROM Players WHERE Nickname = 'Demmarc';
IF @ModeratorID_S7 IS NULL SELECT @ModeratorID_S7 = PlayerID, @ModeratorNickname_S7 = Nickname FROM Players WHERE Nickname = 'System';
SELECT @PremiumPrivilegeID_S7 = PrSrID FROM PrivilegeAndServices WHERE Name = 'Premium';

PRINT '--- 7. Модератор ' + ISNULL(@ModeratorNickname_S7, 'N/A') + ' (ID: ' + ISNULL(CAST(@ModeratorID_S7 AS VARCHAR), 'N/A') + ') выдает игроку ' + ISNULL(@PlayerNickname_S7, 'N/A') + ' (ID: ' + ISNULL(CAST(@TestPlayerID_S7 AS VARCHAR), 'N/A') + ') привилегию Premium (ID: ' + ISNULL(CAST(@PremiumPrivilegeID_S7 AS VARCHAR), 'N/A') + ') ---';

IF @TestPlayerID_S7 IS NOT NULL AND @ModeratorID_S7 IS NOT NULL AND @PremiumPrivilegeID_S7 IS NOT NULL
BEGIN
    EXEC GiveDonation @ModeratorID = @ModeratorID_S7,
                         @TargetPlayerID = @TestPlayerID_S7,
                         @PrSrID = @PremiumPrivilegeID_S7;

    SELECT p.Nickname, ps_active.Name AS CurrentPrivilege
    FROM Players p
    LEFT JOIN PrivilegeAndServices ps_active ON p.ActivePrivilegeID = ps_active.PrSrID
    WHERE p.PlayerID = @TestPlayerID_S7;

    SELECT p.Nickname, ps_donated.Name AS DonatedItem, hd.PaymentDate, hd.Amount
    FROM Players p
    JOIN HistoryDonations hd ON p.PlayerID = hd.PlayerID AND hd.PrSrID = @PremiumPrivilegeID_S7 AND hd.Amount = 0 AND hd.PaymentDate >= DATEADD(minute, -5, GETDATE())
    JOIN PrivilegeAndServices ps_donated ON hd.PrSrID = ps_donated.PrSrID
    WHERE p.PlayerID = @TestPlayerID_S7
    ORDER BY hd.PaymentDate DESC;
END
ELSE
BEGIN
    PRINT 'Ошибка: Не удалось получить ID игрока, модератора или привилегии Premium.';
END
GO

PRINT '';
PRINT '--- Попытка зарегистрировать игрока с существующим никнеймом ---';
DECLARE @TestPlayerNickname_S8 NVARCHAR(100) = 'TestUser_Scenario';
DECLARE @TestPlayerPassword_S8 NVARCHAR(100) = 'AnotherPassword';
EXEC RegisterPlayer @Nickname = @TestPlayerNickname_S8, @PasswordInput = @TestPlayerPassword_S8;
GO


PRINT '';
PRINT '--- Попытка забанить уже забаненного игрока ---';
DECLARE @TestPlayerID_S9 INT, @ModeratorID_S9 INT, @PlayerNickname_S9 NVARCHAR(100);
DECLARE @CalculatedBanEndDate_S9_A DATE, @CalculatedBanEndDate_S9_B DATE; -- Переменные для DATEADD

SELECT @TestPlayerID_S9 = PlayerID, @PlayerNickname_S9 = Nickname FROM Players WHERE Nickname = 'TestUser_Scenario';
SELECT @ModeratorID_S9 = PlayerID FROM Players WHERE Nickname = 'Demmarc';
IF @ModeratorID_S9 IS NULL SELECT @ModeratorID_S9 = PlayerID FROM Players WHERE Nickname = 'System';

IF @TestPlayerID_S9 IS NOT NULL AND @ModeratorID_S9 IS NOT NULL
BEGIN
    PRINT 'Предварительная очистка и бан игрока ' + @PlayerNickname_S9 + ' для теста двойного бана...';
    UPDATE Players SET isBanned = 0 WHERE PlayerID = @TestPlayerID_S9;
    DELETE FROM Unbans WHERE BanID IN (SELECT BanID FROM Bans WHERE PlayerID = @TestPlayerID_S9);
    DELETE FROM Bans WHERE PlayerID = @TestPlayerID_S9;

    SET @CalculatedBanEndDate_S9_A = DATEADD(day, 1, GETDATE()); -- Вычисляем дату
    EXEC BanPlayer @PlayerID = @TestPlayerID_S9, @ModeratorID = @ModeratorID_S9, @Reason = 'Первый бан для теста двойного бана', @BanEndDate = @CalculatedBanEndDate_S9_A, @isPermanentBan = 0;
    SELECT Nickname, isBanned FROM Players WHERE PlayerID = @TestPlayerID_S9;

    PRINT 'Пытаемся забанить игрока ' + @PlayerNickname_S9 + ' второй раз...';
    SET @CalculatedBanEndDate_S9_B = DATEADD(day, 1, GETDATE()); -- Вычисляем дату
    EXEC BanPlayer @PlayerID = @TestPlayerID_S9, @ModeratorID = @ModeratorID_S9, @Reason = 'Второй бан - должен вызвать ошибку', @BanEndDate = @CalculatedBanEndDate_S9_B, @isPermanentBan = 0;
    SELECT Nickname, isBanned FROM Players WHERE PlayerID = @TestPlayerID_S9;
END
ELSE
BEGIN
    PRINT 'Ошибка: Не удалось получить ID игрока или модератора для теста двойного бана.';
END
GO

PRINT '';
PRINT '--- КОНЕЦ ТЕСТОВОГО СЦЕНАРИЯ ---';