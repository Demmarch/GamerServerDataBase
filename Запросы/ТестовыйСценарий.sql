USE [KURS]
GO

-- �������� ����� ��������� PRINT ��� ������������ ���������� ��������
SET NOCOUNT OFF;

PRINT '--- ������ ��������� �������� ---';
GO

-- --- 0. ���������� ���������� ���������� ��� ����� (���� ����� ����� GO �������) ---
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

PRINT '--- 0. ������������� ���������� ���������� � ID ---';

SELECT @GlobalModeratorID = PlayerID FROM Players WHERE Nickname = @InitialModeratorNickname_Global;
IF @GlobalModeratorID IS NULL
BEGIN
    PRINT '����������� ������: ��������� "' + @InitialModeratorNickname_Global + '" �� ������. ������� ������������ "System".';
    SELECT @GlobalModeratorID = PlayerID FROM Players WHERE Nickname = @InitialSystemNickname_Global;
    IF @GlobalModeratorID IS NULL
    BEGIN
        PRINT '����������� ������: ����� "' + @InitialSystemNickname_Global + '" ����� �� ������.';
        RETURN;
    END
    PRINT '��������������: ��������� "' + @InitialModeratorNickname_Global + '" �� ������, ������������ "' + @InitialSystemNickname_Global + '" � �������� ����������.';
END

SELECT @GlobalSystemPlayerID = PlayerID FROM Players WHERE Nickname = @InitialSystemNickname_Global;
IF @GlobalSystemPlayerID IS NULL
BEGIN
    PRINT '����������� ������: ����� "' + @InitialSystemNickname_Global + '" �� ������. �� ��������� ��� ������ ��������� ��������.';
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
    PRINT '����������� ������: ���� ��� ��������� �����/���������� (Unmute, Unban, VIP, Premium) �� ������� ��� ��� ��� �� ������� ����.';
    RETURN;
END

PRINT '���������� ���������� ����������������. ModeratorID: ' + ISNULL(CAST(@GlobalModeratorID AS VARCHAR), 'NULL') +
      ', SystemPlayerID: ' + ISNULL(CAST(@GlobalSystemPlayerID AS VARCHAR), 'NULL') +
      ', UnmuteServiceID: ' + ISNULL(CAST(@UnmuteServiceID_Global AS VARCHAR), 'NULL') + ' (����: ' + ISNULL(CAST(@UnmuteServicePrice_Global AS VARCHAR), 'N/A') + ')' +
      ', UnbanServiceID: ' + ISNULL(CAST(@UnbanServiceID_Global AS VARCHAR), 'NULL') + ' (����: ' + ISNULL(CAST(@UnbanServicePrice_Global AS VARCHAR), 'N/A') + ')' +
      ', VipPrivilegeID: ' + ISNULL(CAST(@VipPrivilegeID_Global AS VARCHAR), 'NULL') + ' (����: ' + ISNULL(CAST(@VipPrivilegePrice_Global AS VARCHAR), 'N/A') + ')' +
      ', PremiumPrivilegeID: ' + ISNULL(CAST(@PremiumPrivilegeID_Global AS VARCHAR), 'NULL');
GO

-- --- 1. ����������� ������ ������ ---
PRINT '';
PRINT '--- 1. ����������� ������ ������: TestUser_Scenario ---';
DECLARE @TestPlayerNickname_S1 NVARCHAR(100) = 'TestUser_Scenario';
DECLARE @TestPlayerPassword_S1 NVARCHAR(100) = 'TestPassword123';
DECLARE @RegisteredPlayerID_S1 INT;

IF EXISTS (SELECT 1 FROM Players WHERE Nickname = @TestPlayerNickname_S1)
BEGIN
    PRINT '��������� ����� ' + @TestPlayerNickname_S1 + ' �� ���������� ������. ��������...';
    DECLARE @PlayerToDeleteID_S1 INT;
    SELECT @PlayerToDeleteID_S1 = PlayerID FROM Players WHERE Nickname = @TestPlayerNickname_S1;

    DELETE FROM HistoryDonations WHERE PlayerID = @PlayerToDeleteID_S1;
    DELETE FROM Unbans WHERE BanID IN (SELECT BanID FROM Bans WHERE PlayerID = @PlayerToDeleteID_S1);
    DELETE FROM Bans WHERE PlayerID = @PlayerToDeleteID_S1;
    DELETE FROM UnMutes WHERE MuteID IN (SELECT MuteID FROM Mute WHERE PlayerID = @PlayerToDeleteID_S1);
    DELETE FROM Mute WHERE PlayerID = @PlayerToDeleteID_S1;
    DELETE FROM Players WHERE PlayerID = @PlayerToDeleteID_S1;
    PRINT '����� ' + @TestPlayerNickname_S1 + ' ������.';
END

EXEC RegisterPlayer @Nickname = @TestPlayerNickname_S1, @PasswordInput = @TestPlayerPassword_S1;
SELECT @RegisteredPlayerID_S1 = PlayerID FROM Players WHERE Nickname = @TestPlayerNickname_S1;
PRINT 'ID ������ ������ ' + @TestPlayerNickname_S1 + ': ' + ISNULL(CAST(@RegisteredPlayerID_S1 AS VARCHAR(10)), '�� ������');

SELECT PlayerID, Nickname, RegistrationDate, ActivePrivilegeID, isBanned, isMuted
FROM Players WHERE Nickname = @TestPlayerNickname_S1;
GO

-- --- 2. ��� ����� ������ ---
PRINT '';
DECLARE @TestPlayerID_S2 INT, @ModeratorID_S2 INT, @PlayerNickname_S2 NVARCHAR(100);
DECLARE @CalculatedMuteEndDate_S2 DATE; -- ���������� ��� ���������� DATEADD

SELECT @TestPlayerID_S2 = PlayerID, @PlayerNickname_S2 = Nickname FROM Players WHERE Nickname = 'TestUser_Scenario';
SELECT @ModeratorID_S2 = PlayerID FROM Players WHERE Nickname = 'Demmarc'; 
IF @ModeratorID_S2 IS NULL SELECT @ModeratorID_S2 = PlayerID FROM Players WHERE Nickname = 'System';

PRINT '--- 2. ��� ������ ' + ISNULL(@PlayerNickname_S2, 'N/A') + ' (ID: ' + ISNULL(CAST(@TestPlayerID_S2 AS VARCHAR), 'N/A') + ') ����������� ID ' + ISNULL(CAST(@ModeratorID_S2 AS VARCHAR), 'N/A') + ' ---';

IF @TestPlayerID_S2 IS NOT NULL AND @ModeratorID_S2 IS NOT NULL
BEGIN
    SET @CalculatedMuteEndDate_S2 = DATEADD(day, 7, GETDATE()); -- ��������� ���� �������

    EXEC MutePlayer @PlayerID = @TestPlayerID_S2,
                     @ModeratorID = @ModeratorID_S2,
                     @Reason = '�������� ��� �� ����',
                     @MuteEndDate = @CalculatedMuteEndDate_S2, -- ���������� ����������
                     @isPermanentMute = 0;

    SELECT p.Nickname, p.isMuted, m.Reason, m.StartDate, m.EndDate, m.isPermanent AS MuteIsPermanent
    FROM Players p
    LEFT JOIN Mute m ON p.PlayerID = m.PlayerID AND m.MuteID = (SELECT TOP 1 MuteID FROM Mute subM WHERE subM.PlayerID = p.PlayerID ORDER BY subM.StartDate DESC) 
    WHERE p.PlayerID = @TestPlayerID_S2;
    SELECT * FROM CurrentlyMutedPlayers WHERE PlayerID = @TestPlayerID_S2;
END
ELSE
BEGIN
    PRINT '������: �� ������� �������� ID ������ ��� ���������� ��� ����.';
END
GO

-- --- 3. ����� �������� ������ ---
PRINT '';
DECLARE @TestPlayerID_S3 INT, @PlayerNickname_S3 NVARCHAR(100);
DECLARE @UnmuteServiceID_S3 INT, @UnmuteServicePrice_S3 MONEY;
SELECT @TestPlayerID_S3 = PlayerID, @PlayerNickname_S3 = Nickname FROM Players WHERE Nickname = 'TestUser_Scenario';
SELECT @UnmuteServiceID_S3 = PrSrID, @UnmuteServicePrice_S3 = dbo.GetPriceFromDescription(Description)
FROM PrivilegeAndServices WHERE Name = 'Unmute';

PRINT '--- 3. ����� ' + ISNULL(@PlayerNickname_S3, 'N/A') + ' (ID: ' + ISNULL(CAST(@TestPlayerID_S3 AS VARCHAR), 'N/A') + ') �������� ������ ---';

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
    PRINT '������: �� ������� �������� ID ������, ID ������ ������� ��� ����.';
END
GO

-- --- 4. ������ ����� ---
PRINT '';
DECLARE @TestPlayerID_S4 INT, @ModeratorID_S4 INT, @PlayerNickname_S4 NVARCHAR(100);
DECLARE @CalculatedBanEndDate_S4 DATE; -- ���������� ��� ���������� DATEADD

SELECT @TestPlayerID_S4 = PlayerID, @PlayerNickname_S4 = Nickname FROM Players WHERE Nickname = 'TestUser_Scenario';
SELECT @ModeratorID_S4 = PlayerID FROM Players WHERE Nickname = 'Demmarc';
IF @ModeratorID_S4 IS NULL SELECT @ModeratorID_S4 = PlayerID FROM Players WHERE Nickname = 'System';

PRINT '--- 4. ��� ������ ' + ISNULL(@PlayerNickname_S4, 'N/A') + ' (ID: ' + ISNULL(CAST(@TestPlayerID_S4 AS VARCHAR), 'N/A') + ') ����������� ID ' + ISNULL(CAST(@ModeratorID_S4 AS VARCHAR), 'N/A') + ' ---';

IF @TestPlayerID_S4 IS NOT NULL AND @ModeratorID_S4 IS NOT NULL
BEGIN
    SET @CalculatedBanEndDate_S4 = DATEADD(month, 1, GETDATE()); -- ��������� ���� �������

    EXEC BanPlayer @PlayerID = @TestPlayerID_S4,
                    @ModeratorID = @ModeratorID_S4,
                    @Reason = '�������� ��� �� ����',
                    @BanEndDate = @CalculatedBanEndDate_S4, -- ���������� ����������
                    @isPermanentBan = 0;

    SELECT p.Nickname, p.isBanned, b.Reason, b.StartDate, b.EndDate, b.isPermanent AS BanIsPermanent
    FROM Players p
    LEFT JOIN Bans b ON p.PlayerID = b.PlayerID AND b.BanID = (SELECT TOP 1 BanID FROM Bans subB WHERE subB.PlayerID = p.PlayerID ORDER BY subB.StartDate DESC) 
    WHERE p.PlayerID = @TestPlayerID_S4;
    SELECT * FROM CurrentlyBannedPlayers WHERE PlayerID = @TestPlayerID_S4;
END
ELSE
BEGIN
    PRINT '������: �� ������� �������� ID ������ ��� ���������� ��� ����.';
END
GO

-- --- 5. ����� �������� ������ ---
PRINT '';
DECLARE @TestPlayerID_S5 INT, @PlayerNickname_S5 NVARCHAR(100);
DECLARE @UnbanServiceID_S5 INT, @UnbanServicePrice_S5 MONEY;
SELECT @TestPlayerID_S5 = PlayerID, @PlayerNickname_S5 = Nickname FROM Players WHERE Nickname = 'TestUser_Scenario';
SELECT @UnbanServiceID_S5 = PrSrID, @UnbanServicePrice_S5 = dbo.GetPriceFromDescription(Description)
FROM PrivilegeAndServices WHERE Name = 'Unban';

PRINT '--- 5. ����� ' + ISNULL(@PlayerNickname_S5, 'N/A') + ' (ID: ' + ISNULL(CAST(@TestPlayerID_S5 AS VARCHAR), 'N/A') + ') �������� ������ ---';

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
    PRINT '������: �� ������� �������� ID ������, ID ������ ������� ��� ����.';
END
GO

-- --- 6. ����� �������� ���������� (��������, VIP) ---
PRINT '';
DECLARE @TestPlayerID_S6 INT, @PlayerNickname_S6 NVARCHAR(100);
DECLARE @VipPrivilegeID_S6 INT, @VipPrivilegePrice_S6 MONEY;
SELECT @TestPlayerID_S6 = PlayerID, @PlayerNickname_S6 = Nickname FROM Players WHERE Nickname = 'TestUser_Scenario';
SELECT @VipPrivilegeID_S6 = PrSrID, @VipPrivilegePrice_S6 = dbo.GetPriceFromDescription(Description)
FROM PrivilegeAndServices WHERE Name = 'VIP';

PRINT '--- 6. ����� ' + ISNULL(@PlayerNickname_S6, 'N/A') + ' (ID: ' + ISNULL(CAST(@TestPlayerID_S6 AS VARCHAR), 'N/A') + ') �������� ���������� VIP ---';

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
    PRINT '������: �� ������� �������� ID ������, ID ���������� VIP ��� ����.';
END
GO

-- --- 7. ������ ���� ����� ����, ��� � ���� ���� (��������, Premium) ---
PRINT '';
DECLARE @TestPlayerID_S7 INT, @ModeratorID_S7 INT, @PremiumPrivilegeID_S7 INT;
DECLARE @PlayerNickname_S7 NVARCHAR(100), @ModeratorNickname_S7 NVARCHAR(100);

SELECT @TestPlayerID_S7 = PlayerID, @PlayerNickname_S7 = Nickname FROM Players WHERE Nickname = 'TestUser_Scenario';
SELECT @ModeratorID_S7 = PlayerID, @ModeratorNickname_S7 = Nickname FROM Players WHERE Nickname = 'Demmarc';
IF @ModeratorID_S7 IS NULL SELECT @ModeratorID_S7 = PlayerID, @ModeratorNickname_S7 = Nickname FROM Players WHERE Nickname = 'System';
SELECT @PremiumPrivilegeID_S7 = PrSrID FROM PrivilegeAndServices WHERE Name = 'Premium';

PRINT '--- 7. ��������� ' + ISNULL(@ModeratorNickname_S7, 'N/A') + ' (ID: ' + ISNULL(CAST(@ModeratorID_S7 AS VARCHAR), 'N/A') + ') ������ ������ ' + ISNULL(@PlayerNickname_S7, 'N/A') + ' (ID: ' + ISNULL(CAST(@TestPlayerID_S7 AS VARCHAR), 'N/A') + ') ���������� Premium (ID: ' + ISNULL(CAST(@PremiumPrivilegeID_S7 AS VARCHAR), 'N/A') + ') ---';

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
    PRINT '������: �� ������� �������� ID ������, ���������� ��� ���������� Premium.';
END
GO

PRINT '';
PRINT '--- ������� ���������������� ������ � ������������ ��������� ---';
DECLARE @TestPlayerNickname_S8 NVARCHAR(100) = 'TestUser_Scenario';
DECLARE @TestPlayerPassword_S8 NVARCHAR(100) = 'AnotherPassword';
EXEC RegisterPlayer @Nickname = @TestPlayerNickname_S8, @PasswordInput = @TestPlayerPassword_S8;
GO


PRINT '';
PRINT '--- ������� �������� ��� ����������� ������ ---';
DECLARE @TestPlayerID_S9 INT, @ModeratorID_S9 INT, @PlayerNickname_S9 NVARCHAR(100);
DECLARE @CalculatedBanEndDate_S9_A DATE, @CalculatedBanEndDate_S9_B DATE; -- ���������� ��� DATEADD

SELECT @TestPlayerID_S9 = PlayerID, @PlayerNickname_S9 = Nickname FROM Players WHERE Nickname = 'TestUser_Scenario';
SELECT @ModeratorID_S9 = PlayerID FROM Players WHERE Nickname = 'Demmarc';
IF @ModeratorID_S9 IS NULL SELECT @ModeratorID_S9 = PlayerID FROM Players WHERE Nickname = 'System';

IF @TestPlayerID_S9 IS NOT NULL AND @ModeratorID_S9 IS NOT NULL
BEGIN
    PRINT '��������������� ������� � ��� ������ ' + @PlayerNickname_S9 + ' ��� ����� �������� ����...';
    UPDATE Players SET isBanned = 0 WHERE PlayerID = @TestPlayerID_S9;
    DELETE FROM Unbans WHERE BanID IN (SELECT BanID FROM Bans WHERE PlayerID = @TestPlayerID_S9);
    DELETE FROM Bans WHERE PlayerID = @TestPlayerID_S9;

    SET @CalculatedBanEndDate_S9_A = DATEADD(day, 1, GETDATE()); -- ��������� ����
    EXEC BanPlayer @PlayerID = @TestPlayerID_S9, @ModeratorID = @ModeratorID_S9, @Reason = '������ ��� ��� ����� �������� ����', @BanEndDate = @CalculatedBanEndDate_S9_A, @isPermanentBan = 0;
    SELECT Nickname, isBanned FROM Players WHERE PlayerID = @TestPlayerID_S9;

    PRINT '�������� �������� ������ ' + @PlayerNickname_S9 + ' ������ ���...';
    SET @CalculatedBanEndDate_S9_B = DATEADD(day, 1, GETDATE()); -- ��������� ����
    EXEC BanPlayer @PlayerID = @TestPlayerID_S9, @ModeratorID = @ModeratorID_S9, @Reason = '������ ��� - ������ ������� ������', @BanEndDate = @CalculatedBanEndDate_S9_B, @isPermanentBan = 0;
    SELECT Nickname, isBanned FROM Players WHERE PlayerID = @TestPlayerID_S9;
END
ELSE
BEGIN
    PRINT '������: �� ������� �������� ID ������ ��� ���������� ��� ����� �������� ����.';
END
GO

PRINT '';
PRINT '--- ����� ��������� �������� ---';