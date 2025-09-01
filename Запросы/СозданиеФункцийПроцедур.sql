USE [KURS]
GO

CREATE FUNCTION GetPriceFromDescription (@Description NVARCHAR(MAX))
RETURNS MONEY
AS
BEGIN
    DECLARE @Price MONEY = NULL;
    DECLARE @DelimiterPosition INT;
    DECLARE @PriceString NVARCHAR(MAX);

    SET @DelimiterPosition = CHARINDEX('||', @Description);

    IF @DelimiterPosition > 0
    BEGIN
        SET @PriceString = LTRIM(RTRIM(SUBSTRING(@Description, @DelimiterPosition + 2, LEN(@Description))));
        
        SET @Price = TRY_CAST(@PriceString AS MONEY);
    END
    RETURN @Price;
END
GO

CREATE PROCEDURE PurchaseDonation
    @PlayerID INT,
    @PrSrID INT,
    @PaymentAmount MONEY
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @ItemName NVARCHAR(100), @ItemType NVARCHAR(100), @ItemDescription NVARCHAR(MAX);
        DECLARE @RequiredPrice MONEY;
        DECLARE @TargetPlayerIsBanned BIT, @TargetPlayerIsMuted BIT;

        IF NOT EXISTS (SELECT 1 FROM Players WHERE PlayerID = @PlayerID)
        BEGIN
            RAISERROR('����� �� ������.', 16, 1);
            RETURN;
        END

        SELECT @ItemName = Name, @ItemType = Type, @ItemDescription = Description
        FROM PrivilegeAndServices
        WHERE PrSrID = @PrSrID;

        IF @ItemName IS NULL
        BEGIN
            RAISERROR('���������� ��� ������ �� �������.', 16, 1);
            RETURN;
        END

        SET @RequiredPrice = dbo.GetPriceFromDescription(@ItemDescription);
        IF @RequiredPrice IS NULL
        BEGIN
            RAISERROR('���� ��� ���������� ��� ������ �� ����������.', 16, 1);
            RETURN;
        END
        IF @PaymentAmount < @RequiredPrice
        BEGIN
            RAISERROR('������ ������ ���������.', 16, 1);
            RETURN;
        END

        SELECT @TargetPlayerIsBanned = isBanned, @TargetPlayerIsMuted = isMuted
        FROM Players
        WHERE PlayerID = @PlayerID;

        IF @ItemType = 'Service'
        BEGIN
            IF @ItemName = 'Unban'
            BEGIN
                IF @TargetPlayerIsBanned = 0
                BEGIN
                    RAISERROR('����� �� �������, ������� ������� ����������.', 16, 1);
                    RETURN;
                END
                DECLARE @ActiveBanID INT;
                SELECT TOP 1 @ActiveBanID = BanID
                FROM Bans
                WHERE PlayerID = @PlayerID AND (isPermanent = 1 OR (EndDate IS NOT NULL AND EndDate >= CAST(GETDATE() AS DATE)))
                ORDER BY StartDate DESC;

                IF @ActiveBanID IS NULL
                BEGIN
                    RAISERROR('�� ������ �������� ��� � ������. ���� ���� �������.', 16, 1);
                    RETURN;
                END

                DECLARE @SystemPlayerID INT;
                SELECT @SystemPlayerID = PlayerID FROM Players WHERE Nickname = 'System';

                INSERT INTO Unbans (BanID, ModeratorID, UnbanDate)
                VALUES (@ActiveBanID, @SystemPlayerID, GETDATE());
            END
            ELSE IF @ItemName = 'Unmute'
            BEGIN
                IF @TargetPlayerIsMuted = 0
                BEGIN
                    RAISERROR('����� �� ��������, ������� ������� ����������.', 16, 1);
                    RETURN;
                END
                DECLARE @ActiveMuteID INT;
                SELECT TOP 1 @ActiveMuteID = MuteID
                FROM Mute
                WHERE PlayerID = @PlayerID AND (isPermanent = 1 OR (EndDate IS NOT NULL AND EndDate >= CAST(GETDATE() AS DATE)))
                ORDER BY StartDate DESC;

                IF @ActiveMuteID IS NULL
                BEGIN
                    RAISERROR('��� ��������� ����, ���� ���� �������.', 16, 1);
                    RETURN;
                END

                DECLARE @SystemPlayerID_ForMute INT;
                SELECT @SystemPlayerID_ForMute = PlayerID FROM Players WHERE Nickname = 'System';

                INSERT INTO UnMutes (MuteID, ModeratorID, UnmuteDate)
                VALUES (@ActiveMuteID, @SystemPlayerID_ForMute, GETDATE());
            END
        END

        INSERT INTO HistoryDonations (PlayerID, PrSrID, PaymentDate, Amount)
        VALUES (@PlayerID, @PrSrID, GETDATE(), @PaymentAmount);

        IF @ItemType = 'Privilege'
        BEGIN
            UPDATE Players
            SET ActivePrivilegeID = @PrSrID
            WHERE PlayerID = @PlayerID;
        END

        PRINT 'Purchase successful for PlayerID: ' + CAST(@PlayerID AS VARCHAR) + ' Item: ' + @ItemName;

    END TRY
    BEGIN CATCH
        PRINT 'Error during purchase: ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END
GO

CREATE PROCEDURE GiveDonation
    @ModeratorID INT,
    @TargetPlayerID INT,
    @PrSrID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @ItemName NVARCHAR(100), @ItemType NVARCHAR(100);
        DECLARE @GrantingPlayerNickname NVARCHAR(100), @TargetPlayerNickname NVARCHAR(100);

        IF NOT EXISTS (SELECT 1 FROM Players p JOIN PrivilegeAndServices ps ON p.ActivePrivilegeID = ps.PrSrID
                       WHERE p.PlayerID = @ModeratorID AND ps.Type IN ('Stuff', 'System')) -- Assuming 'Stuff' or 'System' can give donations
        BEGIN
            RAISERROR('Moderator does not have permission or does not exist.', 16, 1);
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Players WHERE PlayerID = @TargetPlayerID)
        BEGIN
            RAISERROR('Target player not found.', 16, 1);
            RETURN;
        END

        SELECT @ItemName = Name, @ItemType = Type
        FROM PrivilegeAndServices
        WHERE PrSrID = @PrSrID;

        IF @ItemName IS NULL
        BEGIN
            RAISERROR('Privilege or Service not found.', 16, 1);
            RETURN;
        END

        SELECT @GrantingPlayerNickname = Nickname FROM Players WHERE PlayerID = @ModeratorID;
        SELECT @TargetPlayerNickname = Nickname FROM Players WHERE PlayerID = @TargetPlayerID;

        INSERT INTO HistoryDonations (PlayerID, PrSrID, PaymentDate, Amount)
        VALUES (@TargetPlayerID, @PrSrID, GETDATE(), 0);

        IF @ItemType = 'Privilege'
        BEGIN
            UPDATE Players
            SET ActivePrivilegeID = @PrSrID
            WHERE PlayerID = @TargetPlayerID;
            PRINT 'Privilege ' + @ItemName + ' given to ' + @TargetPlayerNickname + ' by ' + @GrantingPlayerNickname;
        END
        ELSE IF @ItemType = 'Service'
        BEGIN
            IF @ItemName = 'Unban'
            BEGIN
                IF (SELECT isBanned FROM Players WHERE PlayerID = @TargetPlayerID) = 1
                BEGIN
                    DECLARE @ActiveBanID INT;
                    SELECT TOP 1 @ActiveBanID = BanID
                    FROM Bans
                    WHERE PlayerID = @TargetPlayerID AND (isPermanent = 1 OR (EndDate IS NOT NULL AND EndDate >= CAST(GETDATE() AS DATE)))
                    ORDER BY StartDate DESC;

                    IF @ActiveBanID IS NOT NULL
                    BEGIN
                        INSERT INTO Unbans (BanID, ModeratorID, UnbanDate)
                        VALUES (@ActiveBanID, @ModeratorID, GETDATE());
                        PRINT 'Unban service applied to ' + @TargetPlayerNickname + ' by ' + @GrantingPlayerNickname;
                    END
                    ELSE
                    BEGIN
                         PRINT 'Player ' + @TargetPlayerNickname + ' is flagged as banned, but no active ban record found. Unban service recorded but manual check might be needed.';
                    END
                END
                ELSE
                BEGIN
                    PRINT 'Player ' + @TargetPlayerNickname + ' is not banned. Unban service logged but not applied.';
                END
            END
            ELSE IF @ItemName = 'Unmute'
            BEGIN
                IF (SELECT isMuted FROM Players WHERE PlayerID = @TargetPlayerID) = 1
                BEGIN
                    DECLARE @ActiveMuteID INT;
                    SELECT TOP 1 @ActiveMuteID = MuteID
                    FROM Mute
                    WHERE PlayerID = @TargetPlayerID AND (isPermanent = 1 OR (EndDate IS NOT NULL AND EndDate >= CAST(GETDATE() AS DATE)))
                    ORDER BY StartDate DESC;

                    IF @ActiveMuteID IS NOT NULL
                    BEGIN
                        INSERT INTO UnMutes (MuteID, ModeratorID, UnmuteDate)
                        VALUES (@ActiveMuteID, @ModeratorID, GETDATE());
                        PRINT 'Unmute service applied to ' + @TargetPlayerNickname + ' by ' + @GrantingPlayerNickname;
                    END
                     ELSE
                    BEGIN
                         PRINT 'Player ' + @TargetPlayerNickname + ' is flagged as muted, but no active mute record found. Unmute service recorded but manual check might be needed.';
                    END
                END
                ELSE
                BEGIN
                    PRINT 'Player ' + @TargetPlayerNickname + ' is not muted. Unmute service logged but not applied.';
                END
            END
            ELSE
            BEGIN
                PRINT 'Service ' + @ItemName + ' given to ' + @TargetPlayerNickname + ' by ' + @GrantingPlayerNickname + '. Manual application of service effect may be required if not unban/unmute.';
            END
        END

    END TRY
    BEGIN CATCH
        PRINT 'Error during GiveDonation: ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END
GO

CREATE PROCEDURE BanPlayer
    @PlayerID INT,
    @ModeratorID INT,
    @Reason TEXT,
    @BanEndDate DATETIME2(3),
    @isPermanentBan BIT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO Bans (PlayerID, ModeratorID, Reason, StartDate, EndDate, isPermanent)
        VALUES (@PlayerID, @ModeratorID, @Reason, GETDATE(), @BanEndDate, @isPermanentBan);
    END TRY
    BEGIN CATCH
        PRINT '������ � BanPlayer: ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END
GO


CREATE PROCEDURE MutePlayer
    @PlayerID INT,
    @ModeratorID INT,
    @Reason TEXT,
    @MuteEndDate DATETIME2(3),
    @isPermanentMute BIT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO Mute (PlayerID, ModeratorID, Reason, StartDate, EndDate, isPermanent)
        VALUES (@PlayerID, @ModeratorID, @Reason, GETDATE(), @MuteEndDate, @isPermanentMute);
    END TRY
    BEGIN CATCH
        PRINT '������ � MutePlayer: ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END
GO

CREATE PROCEDURE UnbanPlayer
    @BanID INT,
    @ModeratorID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO Unbans (BanID, ModeratorID, UnbanDate)
        VALUES (@BanID, @ModeratorID, GETDATE());
    END TRY
    BEGIN CATCH
        PRINT '������ � UnbanPlayer: ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END
GO

CREATE PROCEDURE UnMutePlayer
    @MuteID INT,
    @ModeratorID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO UnMutes (MuteID, ModeratorID, UnmuteDate)
        VALUES (@MuteID, @ModeratorID, GETDATE());
    END TRY
    BEGIN CATCH
        PRINT '������ � UnMutePlayer: ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END
GO

CREATE PROCEDURE RegisterPlayer
    @Nickname NVARCHAR(100),
    @PasswordInput NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PasswordHash VARBINARY(32);
    DECLARE @DefaultPlayerRoleID INT;

    SET @PasswordHash = HASHBYTES('SHA2_256', CAST(@PasswordInput AS VARCHAR(MAX)));

    SELECT @DefaultPlayerRoleID = PrSrID FROM PrivilegeAndServices WHERE Name = 'Player';
    IF @DefaultPlayerRoleID IS NULL
    BEGIN
        RAISERROR('���� "Player" �� ��������� �� ������� � PrivilegeAndServices.', 16, 1);
        RETURN;
    END

    BEGIN TRY
        INSERT INTO Players (
            Nickname,
            PasswordHash,
            RegistrationDate,
            ActivePrivilegeID,
            isBanned,
            isMuted
        )
        VALUES (
            @Nickname,
            @PasswordHash,
            GETDATE(),
            @DefaultPlayerRoleID,
            0,
            0
        );
        PRINT '����� ' + @Nickname + ' ������� ��������������� � ������������ ������� � ������� ��������.';
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

CREATE PROCEDURE DeletePlayerByNickname
    @NicknameToDelete NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @PlayerIDToDelete INT;

        SELECT @PlayerIDToDelete = PlayerID FROM Players WHERE Nickname = @NicknameToDelete;

		IF @PlayerIDToDelete = 1
		BEGIN
			RAISERROR('������ ������� System', 16, 1);
			RETURN;
		END

        IF @PlayerIDToDelete IS NULL
        BEGIN
            RAISERROR('����� � ��������� "%s" �� ������.', 16, 1, @NicknameToDelete);
            RETURN;
        END

        PRINT '���������� �������� ������ ' + @NicknameToDelete + ' (ID: ' + CAST(@PlayerIDToDelete AS VARCHAR) + ') � ��������� ������...';

        BEGIN TRANSACTION;

        DELETE FROM HistoryDonations WHERE PlayerID = @PlayerIDToDelete;
        PRINT '������� ������ �� HistoryDonations.';

        DELETE FROM Unbans WHERE BanID IN (SELECT BanID FROM Bans WHERE PlayerID = @PlayerIDToDelete OR ModeratorID = @PlayerIDToDelete);
        DELETE FROM Unbans WHERE ModeratorID = @PlayerIDToDelete;
        PRINT '������� ������ �� Unbans.';

        DELETE FROM Unmutes WHERE MuteID IN (SELECT MuteID FROM Mute WHERE PlayerID = @PlayerIDToDelete OR ModeratorID = @PlayerIDToDelete);
        DELETE FROM Unmutes WHERE ModeratorID = @PlayerIDToDelete;
        PRINT '������� ������ �� Unmutes.';

        DELETE FROM Bans WHERE PlayerID = @PlayerIDToDelete OR ModeratorID = @PlayerIDToDelete;
        PRINT '������� ������ �� Bans.';

        DELETE FROM Mute WHERE PlayerID = @PlayerIDToDelete OR ModeratorID = @PlayerIDToDelete;
        PRINT '������� ������ �� Mute.';

        DELETE FROM Players WHERE PlayerID = @PlayerIDToDelete;
        PRINT '����� ' + @NicknameToDelete + ' ������ �� ������� Players.';

        COMMIT TRANSACTION;
        PRINT '�������� ������ ' + @NicknameToDelete + ' � ��������� ������ ������� ���������.';

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        PRINT '������ ��� �������� ������: ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END
GO

CREATE PROCEDURE SetStaffRights
    @PerformingAdminNickname NVARCHAR(100),
    @TargetPlayerNickname NVARCHAR(100),
    @StaffPrivilegeName NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @PerformingAdminPlayerID INT, @TargetPlayerID INT;
        DECLARE @PerformingAdminPrivilegeID INT, @SystemPrivilegeID INT;
        DECLARE @StaffPrSrID INT, @StaffPrivilegeType NVARCHAR(100);

        SELECT @SystemPrivilegeID = PrSrID FROM PrivilegeAndServices WHERE Name = 'System' AND Type = 'System';
        IF @SystemPrivilegeID IS NULL
        BEGIN
            RAISERROR('��������� ���������� "System" �� �������. �������� ����������.', 16, 1);
            RETURN;
        END

        SELECT @PerformingAdminPlayerID = PlayerID, @PerformingAdminPrivilegeID = ActivePrivilegeID
        FROM Players WHERE Nickname = @PerformingAdminNickname;

        IF @PerformingAdminPlayerID IS NULL
        BEGIN
            RAISERROR('������������� � ��������� "%s" �� ������.', 16, 1, @PerformingAdminNickname);
            RETURN;
        END

        IF @PerformingAdminPrivilegeID <> @SystemPrivilegeID
        BEGIN
            RAISERROR('����� "%s" �� ����� ���� "System" ��� ���������� ���� ��������.', 16, 1, @PerformingAdminNickname);
            RETURN;
        END

        SELECT @TargetPlayerID = PlayerID FROM Players WHERE Nickname = @TargetPlayerNickname;
        IF @TargetPlayerID IS NULL
        BEGIN
            RAISERROR('������� ����� � ��������� "%s" �� ������.', 16, 1, @TargetPlayerNickname);
            RETURN;
        END

        SELECT @StaffPrSrID = PrSrID, @StaffPrivilegeType = Type
        FROM PrivilegeAndServices WHERE Name = @StaffPrivilegeName;

        IF @StaffPrSrID IS NULL
        BEGIN
            RAISERROR('���������� � ��������� "%s" �� �������.', 16, 1, @StaffPrivilegeName);
            RETURN;
        END

        IF @StaffPrivilegeType <> 'Stuff'
        BEGIN
            RAISERROR('���������� "%s" �� �������� �����-����������� (��� ������ ���� "Stuff").', 16, 1, @StaffPrivilegeName);
            RETURN;
        END

        UPDATE Players
        SET ActivePrivilegeID = @StaffPrSrID
        WHERE PlayerID = @TargetPlayerID;

        PRINT '������ ' + @TargetPlayerNickname + ' ������� ����������� �����-����������: ' + @StaffPrivilegeName;

    END TRY
    BEGIN CATCH
        PRINT '������ ��� ��������� �����-����: ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END
GO

CREATE PROCEDURE RemoveStaffRights
    @PerformingAdminNickname NVARCHAR(100),
    @TargetPlayerNickname NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @PerformingAdminPlayerID INT, @TargetPlayerID INT;
        DECLARE @PerformingAdminPrivilegeID INT, @SystemPrivilegeID INT;
        DECLARE @DefaultPlayerPrSrID INT;
        DECLARE @TargetPlayerCurrentPrivilegeID INT, @TargetPlayerCurrentPrivilegeType NVARCHAR(100);

        SELECT @SystemPrivilegeID = PrSrID FROM PrivilegeAndServices WHERE Name = 'System' AND Type = 'System';
        IF @SystemPrivilegeID IS NULL
        BEGIN
            RAISERROR('��������� ���������� "System" �� �������. �������� ����������.', 16, 1);
            RETURN;
        END

        SELECT @PerformingAdminPlayerID = PlayerID, @PerformingAdminPrivilegeID = ActivePrivilegeID
        FROM Players WHERE Nickname = @PerformingAdminNickname;

        IF @PerformingAdminPlayerID IS NULL
        BEGIN
            RAISERROR('������������� � ��������� "%s" �� ������.', 16, 1, @PerformingAdminNickname);
            RETURN;
        END

        IF @PerformingAdminPrivilegeID <> @SystemPrivilegeID
        BEGIN
            RAISERROR('����� "%s" �� ����� ���� "System" ��� ���������� ���� ��������.', 16, 1, @PerformingAdminNickname);
            RETURN;
        END

        SELECT @TargetPlayerID = p.PlayerID, @TargetPlayerCurrentPrivilegeID = p.ActivePrivilegeID, @TargetPlayerCurrentPrivilegeType = ps.Type
        FROM Players p
        LEFT JOIN PrivilegeAndServices ps ON p.ActivePrivilegeID = ps.PrSrID
        WHERE p.Nickname = @TargetPlayerNickname;

        IF @TargetPlayerID IS NULL
        BEGIN
            RAISERROR('������� ����� � ��������� "%s" �� ������.', 16, 1, @TargetPlayerNickname);
            RETURN;
        END

        IF @TargetPlayerCurrentPrivilegeType <> 'Stuff'
        BEGIN
            PRINT '����� ' + @TargetPlayerNickname + ' �� ����� �����-����������. ������� ���������� ���: ' + ISNULL(@TargetPlayerCurrentPrivilegeType, 'N/A') + '. �������� �� ���������.';
            RETURN;
        END

        SELECT @DefaultPlayerPrSrID = PrSrID FROM PrivilegeAndServices WHERE Name = 'Player' AND Type = 'Player';
        IF @DefaultPlayerPrSrID IS NULL
        BEGIN
            RAISERROR('���������� "Player" �� ��������� �� �������. ���������� ����� �����-�����.', 16, 1);
            RETURN;
        END

        UPDATE Players
        SET ActivePrivilegeID = @DefaultPlayerPrSrID
        WHERE PlayerID = @TargetPlayerID;

        PRINT '� ������ ' + @TargetPlayerNickname + ' ������� ����� �����-����������. ����������� ���������� "Player".';

    END TRY
    BEGIN CATCH
        PRINT '������ ��� ������� �����-����: ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END
GO

CREATE PROCEDURE UpdateExpiredStatus
    @Nickname NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @PlayerID INT;

    SELECT @PlayerID = PlayerID FROM Players WHERE Nickname = @Nickname;
    IF @PlayerID IS NULL
    BEGIN
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM Players WHERE PlayerID = @PlayerID AND isBanned = 1)
    BEGIN
        IF NOT EXISTS (
            SELECT 1 FROM Bans
            WHERE PlayerID = @PlayerID AND (isPermanent = 1 OR EndDate >= GETDATE())
        )
        BEGIN
            UPDATE Players SET isBanned = 0 WHERE PlayerID = @PlayerID;
        END
    END

    IF EXISTS (SELECT 1 FROM Players WHERE PlayerID = @PlayerID AND isMuted = 1)
    BEGIN
        IF NOT EXISTS (
            SELECT 1 FROM Mute
            WHERE PlayerID = @PlayerID AND (isPermanent = 1 OR EndDate >= GETDATE())
        )
        BEGIN
            UPDATE Players SET isMuted = 0 WHERE PlayerID = @PlayerID;
        END
    END
END
GO