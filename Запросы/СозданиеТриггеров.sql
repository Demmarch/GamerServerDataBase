USE [KURS]
GO

CREATE TRIGGER TRG_HandleBan
ON Bans
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @PlayerID INT, @ModeratorID INT, @TargetNickname NVARCHAR(100);
    DECLARE @TargetPrivilegeDescription NVARCHAR(MAX);

    SELECT @PlayerID = i.PlayerID, @ModeratorID = i.ModeratorID FROM inserted i;

    SELECT
        @TargetNickname = p.Nickname,
        @TargetPrivilegeDescription = ps.Description
    FROM
        Players p
    LEFT JOIN
        PrivilegeAndServices ps ON p.ActivePrivilegeID = ps.PrSrID
    WHERE
        p.PlayerID = @PlayerID;

    IF @TargetNickname = 'System'
    BEGIN
        RAISERROR('Нельзя забанить системного пользователя.', 16, 1);
        RETURN;
    END

    IF @TargetPrivilegeDescription LIKE '%PROTECTED%'
    BEGIN
        RAISERROR('Игрок %s защищен от бана (PROTECTED).', 16, 1, @TargetNickname);
        RETURN;
    END
    IF NOT EXISTS (SELECT 1 FROM Players WHERE PlayerID = @PlayerID)
    BEGIN
        RAISERROR('Игрок, которого пытаются забанить, не существует.', 16, 1);
        RETURN;
    END
    IF NOT EXISTS (SELECT 1 FROM Players WHERE PlayerID = @ModeratorID)
    BEGIN
        RAISERROR('Модератор, выполняющий действие, не существует.', 16, 1);
        RETURN;
    END
    IF EXISTS (SELECT 1 FROM Players WHERE PlayerID = @PlayerID AND isBanned = 1)
    BEGIN
        RAISERROR('Игрок %s уже забанен.', 16, 1, @TargetNickname);
        RETURN;
    END

    INSERT INTO Bans (PlayerID, ModeratorID, Reason, StartDate, EndDate, isPermanent)
    SELECT PlayerID, ModeratorID, Reason, GETDATE(), EndDate, isPermanent FROM inserted;

    UPDATE Players
    SET isBanned = 1
    WHERE PlayerID = @PlayerID;
END
GO

CREATE TRIGGER TRG_HandleMute
ON Mute
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @PlayerID INT, @ModeratorID INT, @TargetNickname NVARCHAR(100);
    DECLARE @TargetPrivilegeDescription NVARCHAR(MAX);

    SELECT @PlayerID = i.PlayerID, @ModeratorID = i.ModeratorID FROM inserted i;

    SELECT
        @TargetNickname = p.Nickname,
        @TargetPrivilegeDescription = ps.Description
    FROM
        Players p
    LEFT JOIN
        PrivilegeAndServices ps ON p.ActivePrivilegeID = ps.PrSrID
    WHERE
        p.PlayerID = @PlayerID;

    IF @TargetNickname = 'System'
    BEGIN
        RAISERROR('Нельзя ограничить чат системному пользователю.', 16, 1);
        RETURN;
    END

    IF @TargetPrivilegeDescription LIKE '%PROTECTED%'
    BEGIN
        RAISERROR('Игрок %s защищен от ограничения чата (PROTECTED).', 16, 1, @TargetNickname);
        RETURN;
    END
    IF NOT EXISTS (SELECT 1 FROM Players WHERE PlayerID = @PlayerID)
    BEGIN
        RAISERROR('Игрок, которого пытаются замьютить, не существует.', 16, 1);
        RETURN;
    END
    IF NOT EXISTS (SELECT 1 FROM Players WHERE PlayerID = @ModeratorID)
    BEGIN
        RAISERROR('Модератор, выполняющий действие, не существует.', 16, 1);
        RETURN;
    END
    IF EXISTS (SELECT 1 FROM Players WHERE PlayerID = @PlayerID AND isMuted = 1)
    BEGIN
        RAISERROR('Игрок %s уже замьючен.', 16, 1, @TargetNickname);
        RETURN;
    END

    INSERT INTO Mute (PlayerID, ModeratorID, Reason, StartDate, EndDate, isPermanent)
    SELECT PlayerID, ModeratorID, Reason, GETDATE(), EndDate, isPermanent FROM inserted;

    UPDATE Players
    SET isMuted = 1
    WHERE PlayerID = @PlayerID;
END
GO

CREATE TRIGGER TRG_ValidateUnban
ON Unbans
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @BanID INT, @ModeratorID INT, @UnbanDate DATE, @PlayerID_ToUnban INT;

    SELECT @BanID = i.BanID, @ModeratorID = i.ModeratorID, @UnbanDate = i.UnbanDate
    FROM inserted i;

    -- Check if the ban exists
    IF NOT EXISTS (SELECT 1 FROM Bans WHERE BanID = @BanID)
    BEGIN
        RAISERROR('BanID does not exist.', 16, 1);
        RETURN;
    END

    SELECT @PlayerID_ToUnban = PlayerID FROM Bans WHERE BanID = @BanID;

    -- Check if player is actually banned (redundant if Players.isBanned is source of truth, but good for specific BanID)
    -- More importantly, check if the specific ban record is active
    IF NOT EXISTS (
        SELECT 1
        FROM Bans b
        WHERE b.BanID = @BanID
          AND b.PlayerID = @PlayerID_ToUnban
          AND (b.isPermanent = 1 OR (b.EndDate IS NOT NULL AND b.EndDate >= CAST(GETDATE() AS DATE)))
    )
    BEGIN
        RAISERROR('Player is not actively banned under this BanID, or this ban has already expired.', 16, 1);
        RETURN;
    END

    -- Check if moderator exists
    IF NOT EXISTS (SELECT 1 FROM Players WHERE PlayerID = @ModeratorID)
    BEGIN
        RAISERROR('Moderator performing the unban does not exist.', 16, 1);
        RETURN;
    END

    INSERT INTO Unbans (BanID, ModeratorID, UnbanDate)
    VALUES (@BanID, @ModeratorID, @UnbanDate);

    UPDATE Players
    SET isBanned = 0
    WHERE PlayerID = @PlayerID_ToUnban;

    -- Mark the specific ban as ended
    UPDATE Bans
    SET EndDate = @UnbanDate, isPermanent = 0 -- ensure it's not considered permanent anymore
    WHERE BanID = @BanID;
END
GO

CREATE TRIGGER TRG_ValidateUnMute
ON UnMutes
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MuteID INT, @ModeratorID INT, @UnMuteDate DATE, @PlayerID_ToUnMute INT;

    SELECT @MuteID = i.MuteID, @ModeratorID = i.ModeratorID, @UnMuteDate = i.UnmuteDate
    FROM inserted i;

    IF NOT EXISTS (SELECT 1 FROM Mute WHERE MuteID = @MuteID)
    BEGIN
        RAISERROR('MuteID does not exist.', 16, 1);
        RETURN;
    END

    SELECT @PlayerID_ToUnMute = PlayerID FROM Mute WHERE MuteID = @MuteID;

    IF NOT EXISTS (
        SELECT 1
        FROM Mute m
        WHERE m.MuteID = @MuteID
          AND m.PlayerID = @PlayerID_ToUnMute
          AND (m.isPermanent = 1 OR (m.EndDate IS NOT NULL AND m.EndDate >= CAST(GETDATE() AS DATE)))
    )
    BEGIN
        RAISERROR('Player is not actively muted under this MuteID, or this mute has already expired.', 16, 1);
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM Players WHERE PlayerID = @ModeratorID)
    BEGIN
        RAISERROR('Moderator performing the unmute does not exist.', 16, 1);
        RETURN;
    END

    INSERT INTO UnMutes (MuteID, ModeratorID, UnmuteDate)
    VALUES (@MuteID, @ModeratorID, @UnMuteDate);

    UPDATE Players
    SET isMuted = 0
    WHERE PlayerID = @PlayerID_ToUnMute;

    UPDATE Mute
    SET EndDate = @UnMuteDate, isPermanent = 0
    WHERE MuteID = @MuteID;
END
GO
