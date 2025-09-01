USE [KURS]
GO

CREATE VIEW PlayersInfoMain AS
SELECT
    p.Nickname,
    p.RegistrationDate,
    ps.Name AS PrivilegeName,
    p.isBanned,
    b.StartDate AS BanStartDate,
    b.EndDate AS BanEndDate,
    b.isPermanent AS BanIsPermanent,
    p.isMuted,
    m.StartDate AS MuteStartDate,
    m.EndDate AS MuteEndDate,
    m.isPermanent AS MuteIsPermanent
FROM Players p
LEFT JOIN PrivilegeAndServices ps ON p.ActivePrivilegeID = ps.PrSrID
-- Только актуальные баны
LEFT JOIN (
    SELECT * FROM Bans
    WHERE 
        isPermanent = 1 OR
        (EndDate IS NOT NULL AND EndDate >= GETDATE()) -- Сравниваем с текущей датой и временем
) b ON b.PlayerID = p.PlayerID AND b.BanID = (SELECT TOP 1 BanID FROM Bans subB WHERE subB.PlayerID = p.PlayerID AND (subB.isPermanent = 1 OR (subB.EndDate IS NOT NULL AND subB.EndDate >= GETDATE())) ORDER BY subB.StartDate DESC)
-- Только актуальные мьюты
LEFT JOIN (
    SELECT * FROM Mute
    WHERE 
        isPermanent = 1 OR
        (EndDate IS NOT NULL AND EndDate >= GETDATE()) -- Сравниваем с текущей датой и временем
) m ON m.PlayerID = p.PlayerID AND m.MuteID = (SELECT TOP 1 MuteID FROM Mute subM WHERE subM.PlayerID = p.PlayerID AND (subM.isPermanent = 1 OR (subM.EndDate IS NOT NULL AND subM.EndDate >= GETDATE())) ORDER BY subM.StartDate DESC);
GO

CREATE VIEW CurrentlyBannedPlayers
AS
SELECT
    p.Nickname,
    b.Reason AS BanReason,
    b.StartDate AS BanStartDate,
    b.EndDate AS BanEndDate,
    b.isPermanent AS BanIsPermanent,
    modPlayer.Nickname AS ModeratorNickname,
    ps.Name AS PlayerPrivilege
FROM Players p
INNER JOIN Bans b ON p.PlayerID = b.PlayerID
INNER JOIN Players modPlayer ON b.ModeratorID = modPlayer.PlayerID
LEFT JOIN PrivilegeAndServices ps ON p.ActivePrivilegeID = ps.PrSrID
WHERE p.isBanned = 1 
  AND (b.isPermanent = 1 OR (b.EndDate IS NOT NULL AND b.EndDate >= GETDATE()))
  AND b.BanID = (SELECT TOP 1 subB.BanID
                 FROM Bans subB
                 WHERE subB.PlayerID = p.PlayerID
                   AND (subB.isPermanent = 1 OR (subB.EndDate IS NOT NULL AND subB.EndDate >= GETDATE()))
                 ORDER BY subB.StartDate DESC, subB.BanID DESC);
GO

CREATE VIEW CurrentlyMutedPlayers
AS
SELECT
    p.Nickname,
    m.Reason AS MuteReason,
    m.StartDate AS MuteStartDate,
    m.EndDate AS MuteEndDate,
    m.isPermanent AS MuteIsPermanent,
    modPlayer.Nickname AS ModeratorNickname,
    ps.Name AS PlayerPrivilege
FROM Players p
INNER JOIN Mute m ON p.PlayerID = m.PlayerID
INNER JOIN Players modPlayer ON m.ModeratorID = modPlayer.PlayerID
LEFT JOIN PrivilegeAndServices ps ON p.ActivePrivilegeID = ps.PrSrID
WHERE p.isMuted = 1
  AND (m.isPermanent = 1 OR (m.EndDate IS NOT NULL AND m.EndDate >= GETDATE()))
  AND m.MuteID = (SELECT TOP 1 subM.MuteID
                  FROM Mute subM
                  WHERE subM.PlayerID = p.PlayerID
                    AND (subM.isPermanent = 1 OR (subM.EndDate IS NOT NULL AND subM.EndDate >= GETDATE()))
                  ORDER BY subM.StartDate DESC, subM.MuteID DESC);
GO