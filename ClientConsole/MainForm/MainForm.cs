using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Windows.Forms;
using Microsoft.Data.SqlClient;

namespace MainForm
{
    public partial class MainForm : Form
    {
        private string connectionString = "Server=DEMPC;Database=KURS;Trusted_Connection=True;TrustServerCertificate=True;";
        
        private const string SystemNickname = "System";

        // --- User State ---
        private CurrentPlayerInfo? loggedInUser = null;
        private bool isSystemMode = false;
        private CurrentPlayerInfo? originalUserBeforeSystemMode = null;

        // --- Purchase State ---
        private string? pendingPurchaseItemName = null;
        private decimal pendingPurchaseItemPrice = 0;
        private int pendingPurchaseItemPrSrID = 0;
        private enum AppState { Normal, AwaitingPriceConfirmation }
        private AppState currentState = AppState.Normal;

        public MainForm()
        {
            InitializeComponent();
            rtbLogs.Font = new Font("Consolas", 9.75F, FontStyle.Regular, GraphicsUnit.Point);
            LogToConsole("Клиент запущен. Введите /help для списка команд.");
            UpdateFormTitle();
            ApplyTheme(dark: true);
        }

        private void txtCommand_KeyDown(object sender, KeyEventArgs e)
        {
            if (e.KeyCode == Keys.Enter)
            {
                ProcessCommand();
                e.SuppressKeyPress = true; // Предотвращает звуковой сигнал и дальнейшую обработку Enter
            }
        }

        private void LogToConsole(string message, bool isCommand = false)
        {
            if (rtbLogs.InvokeRequired)
            {
                rtbLogs.Invoke(new Action(() => LogToConsoleInternal(message, isCommand)));
            }
            else
            {
                LogToConsoleInternal(message, isCommand);
            }
        }

        private void LogToConsoleInternal(string message, bool isCommand = false)
        {
            if (isCommand)
            {
                rtbLogs.AppendText($"\n> {message}\n");
            }
            else
            {
                rtbLogs.AppendText($"{message}\n");
            }
            rtbLogs.ScrollToCaret();
        }


        private void UpdateFormTitle()
        {
            if (isSystemMode)
            {
                this.Text = $"Клиентская консоль игрового сервера - Режим: {SystemNickname}";
            }
            else if (loggedInUser != null)
            {
                this.Text = $"Клиентская консоль игрового сервера - Пользователь: {loggedInUser.Nickname}";
            }
            else
            {
                this.Text = "Клиентская консоль игрового сервера - Гость";
            }
        }

        private void ProcessCommand()
        {
            string fullCommand = txtCommand.Text.Trim();
            if (string.IsNullOrWhiteSpace(fullCommand)) return;

            // Логируем команду, если это не ввод пароля для /sys
            if (!(fullCommand.ToLower().StartsWith("/sys ") && !isSystemMode))
            {
                LogToConsole(fullCommand, true);
            }


            txtCommand.Clear();

            if (currentState == AppState.AwaitingPriceConfirmation)
            {
                HandlePriceConfirmation(fullCommand);
                return;
            }

            string[] parts = fullCommand.Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length == 0) return;

            string command = parts[0].ToLower();
            string[] args = parts.Skip(1).ToArray();

            try
            {
                switch (command)
                {
                    // Authentication & Session
                    case "/login":
                        HandleLogin(args);
                        break;
                    case "/reg":
                        HandleRegister(args);
                        break;
                    case "/sys":
                        if (args.Length > 0 && !isSystemMode) LogToConsole($"/sys ******", true);
                        HandleSys(args);
                        break;
                    case "/logout":
                        HandleLogout();
                        break;
                    case "/whoami":
                        HandleWhoAmI();
                        break;

                    // General Player Commands
                    case "/say":
                        HandleSay(args);
                        break;
                    case "/fly":
                        HandleFly();
                        break;
                    case "/gm":
                        HandleGameMode(args);
                        break;
                    case "/buy":
                        HandleBuy(args);
                        break;

                    // Moderation Commands
                    case "/kick":
                        HandleKick(args);
                        break;
                    case "/tempban":
                        HandleTempBan(args);
                        break;
                    case "/tempmute":
                        HandleTempMute(args);
                        break;
                    case "/ban":
                        HandlePermanentBan(args);
                        break;
                    case "/mute":
                        HandlePermanentMute(args);
                        break;
                    case "/unban":
                        HandleUnban(args);
                        break;
                    case "/unmute":
                        HandleUnmute(args);
                        break;
                    case "/givedonate":
                        HandleGiveDonate(args);
                        break;

                    // Listing Commands
                    case "/list":
                        HandleList(args);
                        break;

                    // Help
                    case "/help":
                        HandleHelp();
                        break;

                    // System-Only Commands
                    case "/startserver":
                        HandleStartServer();
                        break;
                    case "/shutdown":
                        HandleShutdown();
                        break;
                    case "/setstaff":
                        HandleSetStaff(args);
                        break;
                    case "/removestaff":
                        HandleRemoveStaff(args);
                        break;
                    case "/delete":
                        HandleDeletePlayer(args);
                        break;
                    case "/rename":
                        HandleRenamePlayer(args);
                        break;
                    case "/syshelp":
                        HandleSysHelp();
                        break;

                    default:
                        LogToConsole($"Неизвестная команда: {command}");
                        break;
                }
            }
            catch (SqlException sqlEx)
            {
                LogToConsole($"Ошибка базы данных: {sqlEx.Message}");
            }
            catch (Exception ex)
            {
                LogToConsole($"Произошла ошибка: {ex.Message}");
            }
            UpdateFormTitle();
        }


        #region Authentication and Session
        private void HandleLogin(string[] args)
        {
            if (loggedInUser != null || isSystemMode)
            {
                LogToConsole("Вы уже вошли в систему. Используйте /logout для выхода.");
                return;
            }
            if (args.Length != 2)
            {
                LogToConsole("Использование: /login <никнейм> <пароль>");
                return;
            }
            string nickname = args[0];
            string password = args[1];

            if (nickname.Equals(SystemNickname, StringComparison.OrdinalIgnoreCase))
            {
                LogToConsole("Для входа в System используйте команду /sys <пароль>.");
                return;
            }

            try
            {
                using (SqlConnection conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    using (SqlCommand updateCmd = new SqlCommand("UpdateExpiredStatus", conn))
                    {
                        updateCmd.CommandType = CommandType.StoredProcedure;
                        updateCmd.Parameters.AddWithValue("@Nickname", nickname);
                        updateCmd.ExecuteNonQuery();
                    }
                    string query = "SELECT PlayerID, PasswordHash, ActivePrivilegeID, RegistrationDate, isBanned, isMuted FROM Players WHERE Nickname = @Nickname";
                    using (SqlCommand cmd = new SqlCommand(query, conn))
                    {
                        cmd.Parameters.AddWithValue("@Nickname", nickname);
                        using (SqlDataReader reader = cmd.ExecuteReader())
                        {
                            if (reader.Read())
                            {
                                int playerId = reader.GetInt32(0);
                                byte[] storedHashBytes = (byte[])reader.GetValue(1);
                                int? activePrivilegeId = reader.IsDBNull(2) ? (int?)null : reader.GetInt32(2);
                                DateTime registrationDate = reader.GetDateTime(3);
                                bool isBanned = reader.GetBoolean(4);
                                bool isMuted = reader.GetBoolean(5);

                                byte[] providedPasswordHash;
                                using (var sha256 = System.Security.Cryptography.SHA256.Create())
                                {
                                    providedPasswordHash = sha256.ComputeHash(Encoding.UTF8.GetBytes(password));
                                }

                                if (storedHashBytes.SequenceEqual(providedPasswordHash))
                                {
                                    if (isBanned)
                                    {
                                        LogToConsole($"Ошибка входа: Аккаунт {nickname} забанен.");
                                        return;
                                    }

                                    loggedInUser = new CurrentPlayerInfo
                                    {
                                        PlayerID = playerId,
                                        Nickname = nickname,
                                        ActivePrivilegeID = activePrivilegeId,
                                        RegistrationDate = registrationDate,
                                        IsBanned = isBanned,
                                        IsMuted = isMuted
                                    };
                                    if (loggedInUser.ActivePrivilegeID.HasValue)
                                    {
                                        loggedInUser.PrivilegeName = GetPrivilegeName(loggedInUser.ActivePrivilegeID.Value);
                                        loggedInUser.PrivilegeType = GetPrivilegeType(loggedInUser.ActivePrivilegeID.Value);
                                    }
                                    else
                                    {
                                        loggedInUser.PrivilegeName = "Нет";
                                    }
                                    LogToConsole($"Добро пожаловать, {nickname}!");
                                }
                                else
                                {
                                    LogToConsole("Ошибка входа: Неверный никнейм или пароль.");
                                }
                            }
                            else
                            {
                                LogToConsole("Ошибка входа: Неверный никнейм или пароль.");
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                LogToConsole($"Ошибка при входе: {ex.Message}");
            }
        }

        private void HandleRegister(string[] args)
        {
            if (loggedInUser != null || isSystemMode)
            {
                LogToConsole("Вы уже вошли в систему. Используйте /logout для выхода перед регистрацией нового аккаунта.");
                return;
            }
            if (args.Length < 2)
            {
                LogToConsole("Использование: /reg <никнейм> <пароль>");
                return;
            }
            string nickname = args[0];
            string password = args[1];

            if (nickname.Equals(SystemNickname, StringComparison.OrdinalIgnoreCase))
            {
                LogToConsole("Никнейм 'System' зарезервирован.");
                return;
            }

            try
            {
                using (SqlConnection conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    using (SqlCommand cmd = new SqlCommand("RegisterPlayer", conn))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.AddWithValue("@Nickname", nickname);
                        cmd.Parameters.AddWithValue("@PasswordInput", password);
                        cmd.ExecuteNonQuery();
                        LogToConsole($"Аккаунт {nickname} успешно зарегистрирован. Теперь вы можете войти с помощью /login.");
                    }
                }
            }
            catch (SqlException sqlEx)
            {
                LogToConsole($"Ошибка регистрации (БД): {sqlEx.Message}");
            }
            catch (Exception ex)
            {
                LogToConsole($"Ошибка регистрации: {ex.Message}");
            }
        }

        private void HandleSys(string[] args)
        {
            if (isSystemMode)
            {
                LogToConsole("Вы уже в режиме System.");
                return;
            }
            if (args.Length < 1)
            {
                LogToConsole("Использование: /sys <пароль>");
                return;
            }
            string password = args[0];

            try
            {
                using (SqlConnection conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    string query = "SELECT PasswordHash FROM Players WHERE Nickname = @Nickname";
                    using (SqlCommand cmd = new SqlCommand(query, conn))
                    {
                        cmd.Parameters.AddWithValue("@Nickname", SystemNickname);

                        object result = cmd.ExecuteScalar();

                        if (result != null && result != DBNull.Value)
                        {
                            byte[] storedHashBytes = (byte[])result;

                            byte[] providedPasswordHash;
                            using (var sha256 = System.Security.Cryptography.SHA256.Create())
                            {
                                providedPasswordHash = sha256.ComputeHash(Encoding.UTF8.GetBytes(password));
                            }

                            if (storedHashBytes.SequenceEqual(providedPasswordHash))
                            {
                                if (loggedInUser != null)
                                {
                                    originalUserBeforeSystemMode = loggedInUser;
                                }
                                isSystemMode = true;
                                LogToConsole("Вход в режим System выполнен успешно.");
                                UpdateFormTitle();
                            }
                            else
                            {
                                LogToConsole("Неверный пароль для System.");
                            }
                        }
                        else
                        {
                            LogToConsole("Критическая ошибка: Системный пользователь не найден в базе данных.");
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                LogToConsole($"Ошибка при попытке входа в режим System: {ex.Message}");
            }
        }

        private void HandleLogout()
        {
            if (isSystemMode)
            {
                isSystemMode = false;
                LogToConsole("Выход из режима System.");
                if (originalUserBeforeSystemMode != null)
                {
                    loggedInUser = originalUserBeforeSystemMode;
                    originalUserBeforeSystemMode = null;
                    LogToConsole($"Возвращение к пользователю: {loggedInUser.Nickname}.");
                }
                else
                {
                    loggedInUser = null;
                }
            }
            else if (loggedInUser != null)
            {
                LogToConsole($"Пользователь {loggedInUser.Nickname} вышел из системы.");
                loggedInUser = null;
            }
            else
            {
                LogToConsole("Вы не вошли в систему.");
            }
            currentState = AppState.Normal;
            pendingPurchaseItemName = null;
        }

        private void HandleWhoAmI()
        {
            if (isSystemMode)
            {
                LogToConsole($"Вы действуете как: {SystemNickname}");
                if (originalUserBeforeSystemMode != null)
                {
                    LogToConsole($"  (Первоначальный пользователь: {originalUserBeforeSystemMode.Nickname})");
                }
                var systemInfo = GetPrivilegeDetails(SystemNickname);
                if (systemInfo != null)
                {
                    LogToConsole($"  Привилегия: {systemInfo.PrivilegeName ?? "System"}");
                    LogToConsole($"  Дата регистрации: {systemInfo.RegistrationDate:yyyy-MM-dd HH:mm:ss}");
                }
            }
            else if (loggedInUser != null)
            {
                RefreshLoggedInUserInfo();
                LogToConsole($"Вы вошли как: {loggedInUser.Nickname}");
                LogToConsole($"  ID: {loggedInUser.PlayerID}");
                LogToConsole($"  Дата регистрации: {loggedInUser.RegistrationDate:yyyy-MM-dd HH:mm:ss}");
                LogToConsole($"  Привилегия: {loggedInUser.PrivilegeName ?? "Нет"} (Тип: {loggedInUser.PrivilegeType ?? "N/A"})");
                if (loggedInUser.IsBanned)
                {
                    LogToConsole("  Статус: ЗАБАНЕН");
                    DataTable banDetails = ExecuteQuery("SELECT TOP 1 Reason, StartDate, EndDate, isPermanent FROM Bans WHERE PlayerID = " + loggedInUser.PlayerID + " AND (isPermanent = 1 OR EndDate >= GETDATE()) ORDER BY StartDate DESC");
                    if (banDetails.Rows.Count > 0)
                    {
                        DataRow row = banDetails.Rows[0];
                        LogToConsole($"    Причина: {row["Reason"]}");
                        LogToConsole($"    Дата начала: {((DateTime)row["StartDate"]):yyyy-MM-dd HH:mm:ss}");
                        if (row["isPermanent"] != DBNull.Value && (bool)row["isPermanent"]) LogToConsole($"    Срок: Навсегда");
                        else if (row["EndDate"] != DBNull.Value) LogToConsole($"    Дата окончания: {((DateTime)row["EndDate"]):yyyy-MM-dd HH:mm:ss}");
                    }
                }
                if (loggedInUser.IsMuted)
                {
                    LogToConsole("  Статус чата: ЗАМЬЮЧЕН");
                    DataTable muteDetails = ExecuteQuery("SELECT TOP 1 Reason, StartDate, EndDate, isPermanent FROM Mute WHERE PlayerID = " + loggedInUser.PlayerID + " AND (isPermanent = 1 OR EndDate >= GETDATE()) ORDER BY StartDate DESC");
                    if (muteDetails.Rows.Count > 0)
                    {
                        DataRow row = muteDetails.Rows[0];
                        LogToConsole($"    Причина: {row["Reason"]}");
                        LogToConsole($"    Дата начала: {((DateTime)row["StartDate"]):yyyy-MM-dd HH:mm:ss}");
                        if (row["isPermanent"] != DBNull.Value && (bool)row["isPermanent"]) LogToConsole($"    Срок: Навсегда");
                        else if (row["EndDate"] != DBNull.Value) LogToConsole($"    Дата окончания: {((DateTime)row["EndDate"]):yyyy-MM-dd HH:mm:ss}");
                    }
                }
            }
            else
            {
                LogToConsole("Вы не вошли в систему (Гость).");
            }
        }
        #endregion

        #region General Player Commands
        private void HandleSay(string[] args)
        {
            if (!IsUserOrSystemLoggedIn()) return;
            if (args.Length == 0)
            {
                LogToConsole("Использование: /say <текст>");
                return;
            }
            string text = string.Join(" ", args);
            string speaker = isSystemMode ? SystemNickname : loggedInUser!.Nickname;

            if (!isSystemMode && loggedInUser != null)
            {
                RefreshLoggedInUserInfo();
                if (loggedInUser.IsMuted)
                {
                    LogToConsole("Вы не можете отправлять сообщения, так как ваш чат замьючен.");
                    return;
                }
            }
            LogToConsole($"[{speaker}]: {text}");
        }

        private void HandleFly()
        {
            if (!IsUserOrSystemLoggedIn(checkPrivilege: true, commandForFly: true)) return;
            LogToConsole("Вы взлетели! (Режим полета активирован)");
        }

        private void HandleGameMode(string[] args)
        {
            if (!IsUserOrSystemLoggedIn(checkPrivilege: true, commandForGm: true)) return;
            if (args.Length < 1)
            {
                LogToConsole("Использование: /gm <0|1|2|3>");
                return;
            }
            if (int.TryParse(args[0], out int mode) && mode >= 0 && mode <= 3)
            {
                bool allowed = false;
                if (isSystemMode) allowed = true;
                else if (loggedInUser != null && loggedInUser.PrivilegeName != null)
                {
                    string desc = GetPrivilegeDescription(loggedInUser.ActivePrivilegeID) ?? "";
                    if (loggedInUser.PrivilegeType == "Stuff") allowed = true;
                    else if (desc.Contains($"/gm {mode}")) allowed = true;
                    else if (mode == 0 || mode == 1)
                    {
                        if (desc.Contains("/gm 0") || desc.Contains("/gm 1")) allowed = true;
                    }
                }

                if (allowed) LogToConsole($"Игровой режим изменен на: {mode}");
                else LogToConsole($"Ваша текущая привилегия не позволяет использовать игровой режим {mode}.");
            }
            else
            {
                LogToConsole("Неверный режим игры. Доступные режимы: 0, 1, 2, 3.");
            }
        }

        private void HandleBuy(string[] args)
        {
            if (!IsUserOrSystemLoggedIn(allowSystem: false)) return;
            if (loggedInUser == null) return;

            if (args.Length == 0)
            {
                LogToConsole("Использование: /buy <название привилегии или услуги>");
                return;
            }
            string itemName = string.Join(" ", args);

            try
            {
                using (SqlConnection conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    string query = "SELECT PrSrID, Name, Description, Type FROM PrivilegeAndServices WHERE Name = @ItemName AND (Type = 'Privilege' OR Type = 'Service')";
                    using (SqlCommand cmd = new SqlCommand(query, conn))
                    {
                        cmd.Parameters.AddWithValue("@ItemName", itemName);
                        using (SqlDataReader reader = cmd.ExecuteReader())
                        {
                            if (reader.Read())
                            {
                                pendingPurchaseItemPrSrID = reader.GetInt32(0);
                                pendingPurchaseItemName = reader.GetString(1);
                                string description = reader.IsDBNull(2) ? "" : reader.GetString(2);
                                string itemType = reader.IsDBNull(3) ? "" : reader.GetString(3);

                                Match priceMatch = Regex.Match(description, @"\|\|\s*(\d+(\.\d{1,2})?)");
                                if (priceMatch.Success && decimal.TryParse(priceMatch.Groups[1].Value, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out decimal price))
                                {
                                    pendingPurchaseItemPrice = price;
                                    LogToConsole($"Товар: {pendingPurchaseItemName}");
                                    LogToConsole($"Тип: {itemType}");
                                    LogToConsole($"Цена: {pendingPurchaseItemPrice:C2}");
                                    LogToConsole($"Введите сумму для подтверждения покупки или 'cancel' для отмены.");
                                    currentState = AppState.AwaitingPriceConfirmation;
                                }
                                else
                                {
                                    LogToConsole($"Товар '{itemName}' не доступен для покупки (цена не найдена).");
                                    pendingPurchaseItemName = null;
                                }
                            }
                            else
                            {
                                LogToConsole($"Товар '{itemName}' не найден или не является привилегией/услугой для покупки.");
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                LogToConsole($"Ошибка при получении информации о товаре: {ex.Message}");
                pendingPurchaseItemName = null;
                currentState = AppState.Normal;
            }
        }

        private void HandlePriceConfirmation(string inputText)
        {
            if (inputText.Equals("cancel", StringComparison.OrdinalIgnoreCase))
            {
                LogToConsole("Покупка отменена.");
                currentState = AppState.Normal;
                pendingPurchaseItemName = null;
                return;
            }

            if (decimal.TryParse(inputText, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out decimal enteredAmount))
            {
                if (loggedInUser == null || pendingPurchaseItemName == null)
                {
                    LogToConsole("Ошибка: нет активного пользователя или товара для покупки.");
                    currentState = AppState.Normal;
                    return;
                }

                try
                {
                    using (SqlConnection conn = new SqlConnection(connectionString))
                    {
                        conn.Open();
                        using (SqlCommand cmd = new SqlCommand("PurchaseDonation", conn))
                        {
                            cmd.CommandType = CommandType.StoredProcedure;
                            cmd.Parameters.AddWithValue("@PlayerID", loggedInUser.PlayerID);
                            cmd.Parameters.AddWithValue("@PrSrID", pendingPurchaseItemPrSrID);
                            cmd.Parameters.AddWithValue("@PaymentAmount", enteredAmount);
                            cmd.ExecuteNonQuery();
                            RefreshLoggedInUserInfo();
                        }
                    }
                }
                catch (SqlException sqlEx)
                {
                    LogToConsole($"Ошибка покупки (БД): {sqlEx.Message}");
                    currentState = AppState.Normal;
                    pendingPurchaseItemName = null;
                    return;
                }
                catch (Exception ex)
                {
                    LogToConsole($"Ошибка при совершении покупки: {ex.Message}");
                }
                finally
                {
                    currentState = AppState.Normal;
                    pendingPurchaseItemName = null;
                }
            }
            else
            {
                LogToConsole("Неверный ввод. Введите сумму или 'cancel'.");
            }
        }
        #endregion

        #region Moderation Commands
        private bool CanUserModerate(string commandName)
        {
            if (isSystemMode) return true;
            if (loggedInUser == null) return false;
            RefreshLoggedInUserInfo();

            string priv = loggedInUser.PrivilegeName?.ToLower() ?? "";
            string type = loggedInUser.PrivilegeType?.ToLower() ?? "";

            if (type == "stuff") return true;

            switch (commandName.ToLower())
            {
                case "/kick": return priv.Contains("admin") || priv == "основатель" || priv == "helper" || priv == "moderator";
                case "/tempmute":
                case "/mute":
                    return priv.Contains("admin") || priv == "основатель" || priv == "helper" || priv == "moderator";
                case "/tempban":
                case "/ban":
                    return priv.Contains("admin") || priv == "основатель" || priv == "moderator";
                case "/unban":
                case "/unmute":
                    return priv.Contains("admin") || priv == "основатель" || priv == "moderator" || priv == "helper";
                case "/givedonate":
                    return priv == "administrator" || priv == "dev";
                case "/list":
                    return priv == "administrator" || priv == "moderator" || priv.Contains("admin");
                default:
                    return false;
            }
        }

        private void HandleKick(string[] args)
        {
            if (!IsUserOrSystemLoggedIn(checkPrivilege: true, commandNameForPerms: "/kick")) return;
            if (args.Length < 1)
            {
                LogToConsole("Использование: /kick <никнейм>");
                return;
            }
            string targetNickname = args[0];
            LogToConsole($"Игрок {targetNickname} был кикнут игроком {(isSystemMode ? SystemNickname : loggedInUser!.Nickname)}.");
        }

        private DateTime? ParseTimeDuration(string[] timeArgs, out string reason)
        {
            reason = "";
            List<string> reasonParts = new List<string>();
            DateTime targetDate = DateTime.Now;
            bool timeParsed = false;
            bool reasonStarted = false;

            foreach (string arg in timeArgs)
            {
                Match match = Regex.Match(arg, @"^(\d+)([ymdhns])$", RegexOptions.IgnoreCase);
                if (match.Success && !reasonStarted)
                {
                    int value = int.Parse(match.Groups[1].Value);
                    string unit = match.Groups[2].Value.ToLower();
                    timeParsed = true;

                    switch (unit)
                    {
                        case "y": targetDate = targetDate.AddYears(value); break;
                        case "m": targetDate = targetDate.AddMonths(value); break;
                        case "d": targetDate = targetDate.AddDays(value); break;
                        case "h": targetDate = targetDate.AddHours(value); break;
                        case "n": targetDate = targetDate.AddMinutes(value); break;
                        case "s": targetDate = targetDate.AddSeconds(value); break;
                    }
                }
                else
                {
                    reasonStarted = true;
                    reasonParts.Add(arg);
                }
            }
            reason = string.Join(" ", reasonParts).Trim();
            if (string.IsNullOrWhiteSpace(reason)) reason = "Причина не указана.";

            return timeParsed ? targetDate : (DateTime?)null;
        }


        private void HandleTempBan(string[] args)
        {
            if (!IsUserOrSystemLoggedIn(checkPrivilege: true, commandNameForPerms: "/tempban")) return;
            if (args.Length < 2)
            {
                LogToConsole("Использование: /tempban <никнейм> <время> [причина]");
                LogToConsole("Время: 1y, 1m, 1d, 1h, 1n (минуты), 1s. Пример: /tempban Player1 1m10d2h Читерство");
                return;
            }
            string targetNickname = args[0];
            string reason;
            DateTime? banEndDate = ParseTimeDuration(args.Skip(1).ToArray(), out reason);

            if (!banEndDate.HasValue)
            {
                LogToConsole("Неверный формат времени для /tempban.");
                return;
            }
            if (string.IsNullOrWhiteSpace(reason) || reason == "Причина не указана.") reason = "Нарушение правил (временный бан)";


            int? targetPlayerId = GetPlayerId(targetNickname);
            if (!targetPlayerId.HasValue)
            {
                LogToConsole($"Игрок {targetNickname} не найден.");
                return;
            }
            int moderatorId = isSystemMode ? GetPlayerId(SystemNickname)!.Value : loggedInUser!.PlayerID;

            try
            {
                using (SqlConnection conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    using (SqlCommand cmd = new SqlCommand("BanPlayer", conn))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.AddWithValue("@PlayerID", targetPlayerId.Value);
                        cmd.Parameters.AddWithValue("@ModeratorID", moderatorId);
                        cmd.Parameters.AddWithValue("@Reason", reason);
                        cmd.Parameters.AddWithValue("@BanEndDate", banEndDate.Value);
                        cmd.Parameters.AddWithValue("@isPermanentBan", 0);
                        cmd.ExecuteNonQuery();
                        LogToConsole($"Игрок {targetNickname} временно забанен до {banEndDate.Value:yyyy-MM-dd HH:mm:ss} модератором {(isSystemMode ? SystemNickname : loggedInUser!.Nickname)}. Причина: {reason}");
                    }
                }
            }
            catch (SqlException sqlEx) { LogToConsole($"Ошибка БД при бане: {sqlEx.Message}"); return; }
            catch (Exception ex) { LogToConsole($"Ошибка при бане: {ex.Message}"); }
        }

        private void HandleTempMute(string[] args)
        {
            if (!IsUserOrSystemLoggedIn(checkPrivilege: true, commandNameForPerms: "/tempmute")) return;
            if (args.Length < 2)
            {
                LogToConsole("Использование: /tempmute <никнейм> <время> [причина]");
                LogToConsole("Время: 1y, 1m, 1d, 1h, 1n (минуты), 1s. Пример: /tempmute Player1 7d12h Флуд");
                return;
            }
            string targetNickname = args[0];
            string reason;
            DateTime? muteEndDate = ParseTimeDuration(args.Skip(1).ToArray(), out reason);

            if (!muteEndDate.HasValue)
            {
                LogToConsole("Неверный формат времени для /tempmute.");
                return;
            }
            if (string.IsNullOrWhiteSpace(reason) || reason == "Причина не указана.") reason = "Нарушение правил чата (временный мут)";

            int? targetPlayerId = GetPlayerId(targetNickname);
            if (!targetPlayerId.HasValue)
            {
                LogToConsole($"Игрок {targetNickname} не найден.");
                return;
            }
            int moderatorId = isSystemMode ? GetPlayerId(SystemNickname)!.Value : loggedInUser!.PlayerID;

            try
            {
                using (SqlConnection conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    using (SqlCommand cmd = new SqlCommand("MutePlayer", conn))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.AddWithValue("@PlayerID", targetPlayerId.Value);
                        cmd.Parameters.AddWithValue("@ModeratorID", moderatorId);
                        cmd.Parameters.AddWithValue("@Reason", reason);
                        cmd.Parameters.AddWithValue("@MuteEndDate", muteEndDate.Value);
                        cmd.Parameters.AddWithValue("@isPermanentMute", 0);
                        cmd.ExecuteNonQuery();
                        LogToConsole($"Игроку {targetNickname} временно ограничен чат до {muteEndDate.Value:yyyy-MM-dd HH:mm:ss} модератором {(isSystemMode ? SystemNickname : loggedInUser!.Nickname)}. Причина: {reason}");
                    }
                }
            }
            catch (SqlException sqlEx) { LogToConsole($"Ошибка БД при муте: {sqlEx.Message}"); return; }
            catch (Exception ex) { LogToConsole($"Ошибка при муте: {ex.Message}"); }
        }

        private void HandlePermanentBan(string[] args)
        {
            if (!IsUserOrSystemLoggedIn(checkPrivilege: true, commandNameForPerms: "/ban")) return;
            if (args.Length < 1)
            {
                LogToConsole("Использование: /ban <никнейм> [причина]");
                return;
            }
            string targetNickname = args[0];
            string reason = args.Length > 1 ? string.Join(" ", args.Skip(1)) : "Нарушение правил (перманентный бан)";

            int? targetPlayerId = GetPlayerId(targetNickname);
            if (!targetPlayerId.HasValue)
            {
                LogToConsole($"Игрок {targetNickname} не найден.");
                return;
            }
            int moderatorId = isSystemMode ? GetPlayerId(SystemNickname)!.Value : loggedInUser!.PlayerID;

            try
            {
                using (SqlConnection conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    using (SqlCommand cmd = new SqlCommand("BanPlayer", conn))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.AddWithValue("@PlayerID", targetPlayerId.Value);
                        cmd.Parameters.AddWithValue("@ModeratorID", moderatorId);
                        cmd.Parameters.AddWithValue("@Reason", reason);
                        cmd.Parameters.AddWithValue("@BanEndDate", DBNull.Value);
                        cmd.Parameters.AddWithValue("@isPermanentBan", 1);
                        cmd.ExecuteNonQuery();
                        LogToConsole($"Игрок {targetNickname} перманентно забанен модератором {(isSystemMode ? SystemNickname : loggedInUser!.Nickname)}. Причина: {reason}");
                    }
                }
            }
            catch (SqlException sqlEx) { LogToConsole($"Ошибка БД при перманентном бане: {sqlEx.Message}"); return; }
            catch (Exception ex) { LogToConsole($"Ошибка при перманентном бане: {ex.Message}"); }
        }

        private void HandlePermanentMute(string[] args)
        {
            if (!IsUserOrSystemLoggedIn(checkPrivilege: true, commandNameForPerms: "/mute")) return;
            if (args.Length < 1)
            {
                LogToConsole("Использование: /mute <никнейм> [причина]");
                return;
            }
            string targetNickname = args[0];
            string reason = args.Length > 1 ? string.Join(" ", args.Skip(1)) : "Нарушение правил чата (перманентный мут)";

            int? targetPlayerId = GetPlayerId(targetNickname);
            if (!targetPlayerId.HasValue)
            {
                LogToConsole($"Игрок {targetNickname} не найден.");
                return;
            }
            int moderatorId = isSystemMode ? GetPlayerId(SystemNickname)!.Value : loggedInUser!.PlayerID;

            try
            {
                using (SqlConnection conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    using (SqlCommand cmd = new SqlCommand("MutePlayer", conn))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.AddWithValue("@PlayerID", targetPlayerId.Value);
                        cmd.Parameters.AddWithValue("@ModeratorID", moderatorId);
                        cmd.Parameters.AddWithValue("@Reason", reason);
                        cmd.Parameters.AddWithValue("@MuteEndDate", DBNull.Value);
                        cmd.Parameters.AddWithValue("@isPermanentMute", 1);
                        cmd.ExecuteNonQuery();
                        LogToConsole($"Игроку {targetNickname} перманентно ограничен чат модератором {(isSystemMode ? SystemNickname : loggedInUser!.Nickname)}. Причина: {reason}");
                    }
                }
            }
            catch (SqlException sqlEx) { LogToConsole($"Ошибка БД при перманентном муте: {sqlEx.Message}"); return; }
            catch (Exception ex) { LogToConsole($"Ошибка при перманентном муте: {ex.Message}"); }
        }

        private void HandleUnban(string[] args)
        {
            if (!IsUserOrSystemLoggedIn(checkPrivilege: true, commandNameForPerms: "/unban")) return;
            if (args.Length < 1)
            {
                LogToConsole("Использование: /unban <никнейм>");
                return;
            }
            string targetNickname = args[0];
            int? targetPlayerId = GetPlayerId(targetNickname);

            if (!targetPlayerId.HasValue)
            {
                LogToConsole($"Игрок {targetNickname} не найден.");
                return;
            }

            int? activeBanId = null;
            try
            {
                using (SqlConnection conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    string query = "SELECT TOP 1 BanID FROM Bans WHERE PlayerID = @PlayerID AND (isPermanent = 1 OR EndDate >= GETDATE()) ORDER BY StartDate DESC";
                    using (SqlCommand cmd = new SqlCommand(query, conn))
                    {
                        cmd.Parameters.AddWithValue("@PlayerID", targetPlayerId.Value);
                        object result = cmd.ExecuteScalar();
                        if (result != null && result != DBNull.Value) activeBanId = Convert.ToInt32(result);
                    }
                }
            }
            catch (Exception ex) { LogToConsole($"Ошибка при поиске активного бана: {ex.Message}"); return; }

            if (!activeBanId.HasValue)
            {
                LogToConsole($"Игрок {targetNickname} не имеет активных банов.");
                using (SqlConnection conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    using (SqlCommand cmd = new SqlCommand("UPDATE Players SET isBanned = 0 WHERE PlayerID = @PlayerID AND isBanned = 1", conn))
                    {
                        cmd.Parameters.AddWithValue("@PlayerID", targetPlayerId.Value);
                        if (cmd.ExecuteNonQuery() > 0) LogToConsole($"Флаг isBanned был сброшен для {targetNickname}.");
                    }
                }
                return;
            }

            int moderatorId = isSystemMode ? GetPlayerId(SystemNickname)!.Value : loggedInUser!.PlayerID;

            try
            {
                using (SqlConnection conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    using (SqlCommand cmd = new SqlCommand("UnbanPlayer", conn))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.AddWithValue("@BanID", activeBanId.Value);
                        cmd.Parameters.AddWithValue("@ModeratorID", moderatorId);
                        cmd.ExecuteNonQuery();
                        LogToConsole($"Игрок {targetNickname} разбанен модератором {(isSystemMode ? SystemNickname : loggedInUser!.Nickname)}.");
                    }
                }
            }
            catch (SqlException sqlEx) { LogToConsole($"Ошибка БД при разбане: {sqlEx.Message}"); return; }
            catch (Exception ex) { LogToConsole($"Ошибка при разбане: {ex.Message}"); }
        }

        private void HandleUnmute(string[] args)
        {
            if (!IsUserOrSystemLoggedIn(checkPrivilege: true, commandNameForPerms: "/unmute")) return;
            if (args.Length < 1)
            {
                LogToConsole("Использование: /unmute <никнейм>");
                return;
            }
            string targetNickname = args[0];
            int? targetPlayerId = GetPlayerId(targetNickname);

            if (!targetPlayerId.HasValue)
            {
                LogToConsole($"Игрок {targetNickname} не найден.");
                return;
            }

            int? activeMuteId = null;
            try
            {
                using (SqlConnection conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    string query = "SELECT TOP 1 MuteID FROM Mute WHERE PlayerID = @PlayerID AND (isPermanent = 1 OR EndDate >= GETDATE()) ORDER BY StartDate DESC";
                    using (SqlCommand cmd = new SqlCommand(query, conn))
                    {
                        cmd.Parameters.AddWithValue("@PlayerID", targetPlayerId.Value);
                        object result = cmd.ExecuteScalar();
                        if (result != null && result != DBNull.Value) activeMuteId = Convert.ToInt32(result);
                    }
                }
            }
            catch (Exception ex) { LogToConsole($"Ошибка при поиске активного мута: {ex.Message}"); return; }

            if (!activeMuteId.HasValue)
            {
                LogToConsole($"У игрока {targetNickname} нет активных ограничений чата.");
                using (SqlConnection conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    using (SqlCommand cmd = new SqlCommand("UPDATE Players SET isMuted = 0 WHERE PlayerID = @PlayerID AND isMuted = 1", conn))
                    {
                        cmd.Parameters.AddWithValue("@PlayerID", targetPlayerId.Value);
                        if (cmd.ExecuteNonQuery() > 0) LogToConsole($"Флаг isMuted был сброшен для {targetNickname}.");
                    }
                }
                return;
            }

            int moderatorId = isSystemMode ? GetPlayerId(SystemNickname)!.Value : loggedInUser!.PlayerID;

            try
            {
                using (SqlConnection conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    using (SqlCommand cmd = new SqlCommand("UnMutePlayer", conn))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.AddWithValue("@MuteID", activeMuteId.Value);
                        cmd.Parameters.AddWithValue("@ModeratorID", moderatorId);
                        cmd.ExecuteNonQuery();
                        LogToConsole($"С игрока {targetNickname} сняты ограничения чата модератором {(isSystemMode ? SystemNickname : loggedInUser!.Nickname)}.");
                    }
                }
            }
            catch (SqlException sqlEx) { LogToConsole($"Ошибка БД при размуте: {sqlEx.Message}"); return; }
            catch (Exception ex) { LogToConsole($"Ошибка при размуте: {ex.Message}"); }
        }

        private void HandleGiveDonate(string[] args)
        {
            if (!IsUserOrSystemLoggedIn(checkPrivilege: true, commandNameForPerms: "/givedonate")) return;
            if (args.Length < 2)
            {
                LogToConsole("Использование: /givedonate <никнейм_игрока> <название_привилегии_или_услуги>");
                return;
            }
            string targetNickname = args[0];
            string itemName = string.Join(" ", args.Skip(1));

            int? targetPlayerId = GetPlayerId(targetNickname);
            if (!targetPlayerId.HasValue)
            {
                LogToConsole($"Игрок {targetNickname} не найден.");
                return;
            }

            int? prSrId = GetPrivilegeOrServiceId(itemName);
            if (!prSrId.HasValue)
            {
                LogToConsole($"Привилегия или услуга '{itemName}' не найдена.");
                return;
            }

            int moderatorId = isSystemMode ? GetPlayerId(SystemNickname)!.Value : loggedInUser!.PlayerID;

            try
            {
                using (SqlConnection conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    using (SqlCommand cmd = new SqlCommand("GiveDonation", conn))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.AddWithValue("@ModeratorID", moderatorId);
                        cmd.Parameters.AddWithValue("@TargetPlayerID", targetPlayerId.Value);
                        cmd.Parameters.AddWithValue("@PrSrID", prSrId.Value);
                        cmd.ExecuteNonQuery();
                    }
                }
            }
            catch (SqlException sqlEx) { LogToConsole($"Ошибка БД при выдаче доната: {sqlEx.Message}"); }
            catch (Exception ex) { LogToConsole($"Ошибка при выдаче доната: {ex.Message}"); }
        }
        #endregion

        #region Listing Commands
        private void HandleList(string[] args)
        {
            if (!IsUserOrSystemLoggedIn(checkPrivilege: true, commandNameForPerms: "/list")) return;

            string viewName = "PlayersInfoMain";
            if (args.Length > 0)
            {
                switch (args[0].ToLower())
                {
                    case "bans": viewName = "CurrentlyBannedPlayers"; break;
                    case "mutes": viewName = "CurrentlyMutedPlayers"; break;
                    case "all": viewName = "PlayersInfoMain"; break;
                    default:
                        LogToConsole($"Неизвестный параметр для /list. Доступно: bans, mutes, all.");
                        return;
                }
            }

            DataTable dt = ExecuteQuery($"SELECT * FROM {viewName}");
            if (dt.Rows.Count == 0)
            {
                LogToConsole($"Нет данных для отображения в {viewName}.");
                return;
            }

            StringBuilder sb = new StringBuilder();
            sb.AppendLine($"--- {viewName} ---");
            foreach (DataColumn col in dt.Columns) sb.Append(col.ColumnName.PadRight(20));
            sb.AppendLine();
            sb.AppendLine(new string('-', dt.Columns.Count * 20));
            foreach (DataRow row in dt.Rows)
            {
                foreach (DataColumn col in dt.Columns)
                {
                    string val = row[col]?.ToString() ?? "NULL";
                    if (col.DataType == typeof(DateTime) && row[col] != DBNull.Value) val = ((DateTime)row[col]).ToString("dd-MM-yyyy HH:mm:ss");
                    else if (col.DataType == typeof(bool) && row[col] != DBNull.Value) val = (bool)row[col] ? "Да" : "Нет";
                    sb.Append(val.PadRight(20));
                }
                sb.AppendLine();
            }
            LogToConsole(sb.ToString());
        }
        #endregion

        #region Help
        private void HandleHelp()
        {
            StringBuilder helpText = new StringBuilder();
            helpText.AppendLine("--- Доступные команды ---");

            if (!isSystemMode && loggedInUser == null) // Гость
            {
                helpText.AppendLine("/login <никнейм> <пароль> - Войти в существующий аккаунт.");
                helpText.AppendLine("/reg <никнейм> <пароль> - Зарегистрировать новый аккаунт.");
                helpText.AppendLine("/sys <пароль> - Войти в режим System.");
            }
            else // Залогиненный пользователь или System
            {
                if (!isSystemMode) helpText.AppendLine("/logout - Выйти из аккаунта.");
                else helpText.AppendLine("/logout - Выйти из режима System.");

                helpText.AppendLine("/whoami - Показать информацию о текущем пользователе.");
                helpText.AppendLine("/say <текст> - Отправить сообщение в чат.");

                CurrentPlayerInfo? effectiveUser = isSystemMode ? GetPrivilegeDetails(SystemNickname) : loggedInUser;
                if (effectiveUser != null)
                {
                    string privDesc = GetPrivilegeDescription(effectiveUser.ActivePrivilegeID) ?? "";
                    string type = effectiveUser.PrivilegeType?.ToLower() ?? "";
                    bool isStaff = type == "stuff";

                    if (isSystemMode || isStaff || privDesc.Contains("/fly")) helpText.AppendLine("/fly - Активировать режим полета.");
                    if (isSystemMode || isStaff || privDesc.Contains("/gm")) helpText.AppendLine("/gm <0-3> - Изменить игровой режим.");
                    if (!isSystemMode) helpText.AppendLine("/buy <название> - Начать покупку привилегии или услуги.");

                    if (CanUserModerate("/kick")) helpText.AppendLine("/kick <никнейм> - Кикнуть игрока (только сообщение).");
                    if (CanUserModerate("/tempmute")) helpText.AppendLine("/tempmute <никнейм> <время> [причина] - Временно ограничить чат игроку.");
                    if (CanUserModerate("/unmute")) helpText.AppendLine("/unmute <никнейм> - Снять ограничения чата с игрока.");
                    if (CanUserModerate("/list")) helpText.AppendLine("/list [bans|mutes|all] - Показать списки игроков.");
                    if (CanUserModerate("/tempban")) helpText.AppendLine("/tempban <никнейм> <время> [причина] - Временно забанить игрока.");
                    if (CanUserModerate("/unban")) helpText.AppendLine("/unban <никнейм> - Разбанить игрока.");
                    if (CanUserModerate("/ban")) helpText.AppendLine("/ban <никнейм> [причина] - Перманентно забанить игрока.");
                    if (CanUserModerate("/mute")) helpText.AppendLine("/mute <никнейм> [причина] - Перманентно ограничить чат игроку.");
                    if (CanUserModerate("/givedonate")) helpText.AppendLine("/givedonate <игрок> <название> - Выдать донат игроку.");
                }
            }
            helpText.AppendLine("/help - Показать это сообщение.");
            if (isSystemMode) helpText.AppendLine("/syshelp - Показать команды System.");
            LogToConsole(helpText.ToString());
        }
        #endregion

        #region System-Only Commands
        private bool IsSystem()
        {
            if (!isSystemMode)
            {
                LogToConsole("Эта команда доступна только в режиме System.");
                return false;
            }
            return true;
        }

        private void HandleStartServer()
        {
            if (!IsSystem()) return;
            LogToConsole("Server is running (симуляция).");
        }

        private void HandleShutdown()
        {
            if (!IsSystem()) return;
            LogToConsole("Приложение закрывается...");
            Application.Exit();
        }

        private void HandleSetStaff(string[] args)
        {
            if (!IsSystem()) return;
            if (args.Length < 2)
            {
                LogToConsole("Использование: /setstaff <никнейм_игрока> <название_стафф_привилегии>");
                LogToConsole("Примеры стафф-привилегий: Moderator, Helper, ADMINISTRATOR, DEV");
                return;
            }
            string targetNickname = args[0];
            string staffPrivilegeName = args[1];

            try
            {
                using (SqlConnection conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    using (SqlCommand cmd = new SqlCommand("SetStaffRights", conn))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.AddWithValue("@PerformingAdminNickname", SystemNickname);
                        cmd.Parameters.AddWithValue("@TargetPlayerNickname", targetNickname);
                        cmd.Parameters.AddWithValue("@StaffPrivilegeName", staffPrivilegeName);
                        cmd.ExecuteNonQuery();
                    }
                }
            }
            catch (SqlException sqlEx) { LogToConsole($"Ошибка БД: {sqlEx.Message}"); return; }
            catch (Exception ex) { LogToConsole($"Ошибка: {ex.Message}"); }
        }

        private void HandleRemoveStaff(string[] args)
        {
            if (!IsSystem()) return;
            if (args.Length < 1)
            {
                LogToConsole("Использование: /removestaff <никнейм_игрока>");
                return;
            }
            string targetNickname = args[0];
            try
            {
                using (SqlConnection conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    using (SqlCommand cmd = new SqlCommand("RemoveStaffRights", conn))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.AddWithValue("@PerformingAdminNickname", SystemNickname);
                        cmd.Parameters.AddWithValue("@TargetPlayerNickname", targetNickname);
                        cmd.ExecuteNonQuery();
                    }
                }
            }
            catch (SqlException sqlEx) { LogToConsole($"Ошибка БД: {sqlEx.Message}"); return; }
            catch (Exception ex) { LogToConsole($"Ошибка: {ex.Message}"); }
        }

        private void HandleDeletePlayer(string[] args)
        {
            if (!IsSystem()) return;
            if (args.Length < 1)
            {
                LogToConsole("Использование: /delete <никнейм_игрока>");
                return;
            }
            string targetNickname = args[0];

            if (targetNickname.Equals(SystemNickname, StringComparison.OrdinalIgnoreCase))
            {
                LogToConsole("Нельзя удалить аккаунт System.");
                return;
            }

            DialogResult confirmResult = MessageBox.Show($"Вы уверены, что хотите удалить игрока {targetNickname} и все связанные с ним данные? Это действие необратимо.",
                                         "Подтверждение удаления", MessageBoxButtons.YesNo, MessageBoxIcon.Warning);
            if (confirmResult == DialogResult.No)
            {
                LogToConsole("Удаление отменено.");
                return;
            }

            try
            {
                using (SqlConnection conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    using (SqlCommand cmd = new SqlCommand("DeletePlayerByNickname", conn))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.AddWithValue("@NicknameToDelete", targetNickname);
                        cmd.ExecuteNonQuery();
                    }
                }
            }
            catch (SqlException sqlEx) { LogToConsole($"Ошибка БД: {sqlEx.Message}"); return; }
            catch (Exception ex) { LogToConsole($"Ошибка: {ex.Message}"); }
        }

        private void HandleRenamePlayer(string[] args)
        {
            if (!IsSystem()) return;
            if (args.Length < 2)
            {
                LogToConsole("Использование: /rename <старый_никнейм> <новый_никнейм>");
                return;
            }
            string oldNickname = args[0];
            string newNickname = args[1];

            if (oldNickname.Equals(SystemNickname, StringComparison.OrdinalIgnoreCase) ||
                newNickname.Equals(SystemNickname, StringComparison.OrdinalIgnoreCase))
            {
                LogToConsole("Нельзя переименовать аккаунт System или в System.");
                return;
            }

            try
            {
                using (SqlConnection conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    string query = "UPDATE Players SET Nickname = @NewNickname WHERE Nickname = @OldNickname";
                    using (SqlCommand cmd = new SqlCommand(query, conn))
                    {
                        cmd.Parameters.AddWithValue("@NewNickname", newNickname);
                        cmd.Parameters.AddWithValue("@OldNickname", oldNickname);
                        int rowsAffected = cmd.ExecuteNonQuery();
                        if (rowsAffected > 0)
                        {
                            LogToConsole($"Игрок {oldNickname} успешно переименован в {newNickname}.");
                            if (loggedInUser != null && loggedInUser.Nickname == oldNickname) loggedInUser.Nickname = newNickname;
                            if (originalUserBeforeSystemMode != null && originalUserBeforeSystemMode.Nickname == oldNickname) originalUserBeforeSystemMode.Nickname = newNickname;
                        }
                        else
                        {
                            LogToConsole($"Игрок {oldNickname} не найден.");
                        }
                    }
                }
            }
            catch (SqlException sqlEx)
            {
                LogToConsole($"Ошибка БД при переименовании (возможно, новый никнейм занят): {sqlEx.Message}");
                return;
            }
            catch (Exception ex)
            {
                LogToConsole($"Ошибка при переименовании: {ex.Message}");
            }
        }

        private void HandleSysHelp()
        {
            if (!IsSystem()) return;
            LogToConsole("--- Команды System ---");
            LogToConsole("/startserver - Запустить сервер (симуляция).");
            LogToConsole("/shutdown - Закрыть клиентское приложение.");
            LogToConsole("/setstaff <игрок> <привилегия> - Назначить стафф-привилегию.");
            LogToConsole("/removestaff <игрок> - Снять стафф-привилегию.");
            LogToConsole("/delete <игрок> - Удалить игрока и все его данные.");
            LogToConsole("/rename <старый_ник> <новый_ник> - Переименовать игрока.");
            LogToConsole("/syshelp - Показать это сообщение.");
            LogToConsole("--- Общие команды также доступны ---");
            HandleHelp();
        }
        #endregion

        #region Helper Methods
        private bool IsUserOrSystemLoggedIn(bool allowSystem = true, bool checkPrivilege = false, string[]? requiredPrivilegeType = null, string? commandNameForPerms = null, bool commandForFly = false, bool commandForGm = false)
        {
            if (isSystemMode)
            {
                if (!allowSystem && commandNameForPerms != "/buy") { } // System может почти всё
                return true;
            }

            if (loggedInUser == null)
            {
                LogToConsole("Вы должны войти в систему для выполнения этой команды. Используйте /login или /reg.");
                return false;
            }

            RefreshLoggedInUserInfo();

            if (loggedInUser.IsBanned && commandNameForPerms != "/buy" && commandNameForPerms != "/whoami" && commandNameForPerms != "/logout")
            {
                LogToConsole("Вы забанены и не можете выполнять большинство команд.");
                return false;
            }

            if (checkPrivilege)
            {
                bool hasPermission = false;
                if (commandForFly)
                {
                    string desc = GetPrivilegeDescription(loggedInUser.ActivePrivilegeID) ?? "";
                    if (desc.Contains("/fly", StringComparison.OrdinalIgnoreCase) || loggedInUser.PrivilegeType == "Stuff") hasPermission = true;
                }
                else if (commandForGm)
                {
                    string desc = GetPrivilegeDescription(loggedInUser.ActivePrivilegeID) ?? "";
                    if (desc.Contains("/gm", StringComparison.OrdinalIgnoreCase) || loggedInUser.PrivilegeType == "Stuff") hasPermission = true;
                }
                else if (requiredPrivilegeType != null && requiredPrivilegeType.Length > 0)
                {
                    if (loggedInUser.PrivilegeType != null && requiredPrivilegeType.Contains(loggedInUser.PrivilegeType, StringComparer.OrdinalIgnoreCase)) hasPermission = true;
                }
                else if (!string.IsNullOrEmpty(commandNameForPerms))
                {
                    hasPermission = CanUserModerate(commandNameForPerms);
                }

                if (!hasPermission)
                {
                    LogToConsole("У вас недостаточно прав для выполнения этой команды.");
                    return false;
                }
            }
            return true;
        }

        private string? GetPrivilegeDescription(int? privilegeId)
        {
            if (!privilegeId.HasValue) return null;
            try
            {
                using (SqlConnection conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    using (SqlCommand cmd = new SqlCommand("SELECT Description FROM PrivilegeAndServices WHERE PrSrID = @PrSrID", conn))
                    {
                        cmd.Parameters.AddWithValue("@PrSrID", privilegeId.Value);
                        return cmd.ExecuteScalar()?.ToString();
                    }
                }
            }
            catch { return null; }
        }

        private int? GetPlayerId(string nickname)
        {
            try
            {
                using (SqlConnection conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    using (SqlCommand cmd = new SqlCommand("SELECT PlayerID FROM Players WHERE Nickname = @Nickname", conn))
                    {
                        cmd.Parameters.AddWithValue("@Nickname", nickname);
                        object result = cmd.ExecuteScalar();
                        if (result != null && result != DBNull.Value) return Convert.ToInt32(result);
                    }
                }
            }
            catch (Exception ex) { LogToConsole($"Ошибка при получении ID игрока {nickname}: {ex.Message}"); }
            return null;
        }

        private int? GetPrivilegeOrServiceId(string name)
        {
            try
            {
                using (SqlConnection conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    using (SqlCommand cmd = new SqlCommand("SELECT PrSrID FROM PrivilegeAndServices WHERE Name = @Name", conn))
                    {
                        cmd.Parameters.AddWithValue("@Name", name);
                        object result = cmd.ExecuteScalar();
                        if (result != null && result != DBNull.Value) return Convert.ToInt32(result);
                    }
                }
            }
            catch (Exception ex) { LogToConsole($"Ошибка при получении ID привилегии/услуги {name}: {ex.Message}"); }
            return null;
        }

        private string? GetPrivilegeName(int privilegeId)
        {
            try
            {
                using (SqlConnection conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    using (SqlCommand cmd = new SqlCommand("SELECT Name FROM PrivilegeAndServices WHERE PrSrID = @PrSrID", conn))
                    {
                        cmd.Parameters.AddWithValue("@PrSrID", privilegeId);
                        return cmd.ExecuteScalar()?.ToString();
                    }
                }
            }
            catch { return null; }
        }
        private string? GetPrivilegeType(int privilegeId)
        {
            try
            {
                using (SqlConnection conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    using (SqlCommand cmd = new SqlCommand("SELECT Type FROM PrivilegeAndServices WHERE PrSrID = @PrSrID", conn))
                    {
                        cmd.Parameters.AddWithValue("@PrSrID", privilegeId);
                        return cmd.ExecuteScalar()?.ToString();
                    }
                }
            }
            catch { return null; }
        }

        private CurrentPlayerInfo? GetPrivilegeDetails(string nickname)
        {
            CurrentPlayerInfo? info = null;
            try
            {
                using (SqlConnection conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    string query = @"
                        SELECT p.PlayerID, p.Nickname, p.RegistrationDate, p.ActivePrivilegeID, ps.Name AS PrivilegeName, ps.Type as PrivilegeType, p.isBanned, p.isMuted
                        FROM Players p
                        LEFT JOIN PrivilegeAndServices ps ON p.ActivePrivilegeID = ps.PrSrID
                        WHERE p.Nickname = @Nickname";
                    using (SqlCommand cmd = new SqlCommand(query, conn))
                    {
                        cmd.Parameters.AddWithValue("@Nickname", nickname);
                        using (SqlDataReader reader = cmd.ExecuteReader())
                        {
                            if (reader.Read())
                            {
                                info = new CurrentPlayerInfo
                                {
                                    PlayerID = reader.GetInt32(reader.GetOrdinal("PlayerID")),
                                    Nickname = reader.GetString(reader.GetOrdinal("Nickname")),
                                    RegistrationDate = reader.GetDateTime(reader.GetOrdinal("RegistrationDate")),
                                    ActivePrivilegeID = reader.IsDBNull(reader.GetOrdinal("ActivePrivilegeID")) ? (int?)null : reader.GetInt32(reader.GetOrdinal("ActivePrivilegeID")),
                                    PrivilegeName = reader.IsDBNull(reader.GetOrdinal("PrivilegeName")) ? "Нет" : reader.GetString(reader.GetOrdinal("PrivilegeName")),
                                    PrivilegeType = reader.IsDBNull(reader.GetOrdinal("PrivilegeType")) ? null : reader.GetString(reader.GetOrdinal("PrivilegeType")),
                                    IsBanned = reader.GetBoolean(reader.GetOrdinal("isBanned")),
                                    IsMuted = reader.GetBoolean(reader.GetOrdinal("isMuted"))
                                };
                            }
                        }
                    }
                }
            }
            catch (Exception ex) { LogToConsole($"Ошибка при получении деталей привилегии для {nickname}: {ex.Message}"); }
            return info;
        }

        private void RefreshLoggedInUserInfo()
        {
            if (loggedInUser == null) return;

            try
            {
                using (SqlConnection conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    using (SqlCommand updateCmd = new SqlCommand("UpdateExpiredStatus", conn))
                    {
                        updateCmd.CommandType = CommandType.StoredProcedure;
                        updateCmd.Parameters.AddWithValue("@Nickname", loggedInUser.Nickname);
                        updateCmd.ExecuteNonQuery();
                    }
                }
            }
            catch (Exception ex)
            {
                LogToConsole($"Служебная ошибка при обновлении статуса: {ex.Message}");
            }

            CurrentPlayerInfo? updatedInfo = GetPrivilegeDetails(loggedInUser.Nickname);
            if (updatedInfo != null)
            {
                loggedInUser = updatedInfo;
            }
        }

        private DataTable ExecuteQuery(string query)
        {
            DataTable dt = new DataTable();
            using (SqlConnection conn = new SqlConnection(connectionString))
            {
                conn.Open();
                using (SqlCommand cmd = new SqlCommand(query, conn))
                {
                    using (SqlDataAdapter adapter = new SqlDataAdapter(cmd))
                    {
                        adapter.Fill(dt);
                    }
                }
            }
            return dt;
        }
        #endregion

        #region Theme Handling


        private void themeDark_Click(object sender, EventArgs e)
        {
            ApplyTheme(dark: true);
        }

        private void themeLight_Click(object sender, EventArgs e)
        {
            ApplyTheme(dark: false);
        }

        private void ApplyTheme(bool dark)
        {
            Color bgTextboxes, fgTextboxes, bgMenu, fgMenuText, bgMenuItems, fgMenuItems;

            if (dark)
            {
                this.BackColor = Color.FromArgb(50, 50, 50); // Общий фон формы
                fgTextboxes = SystemColors.Window; // Белый текст
                bgTextboxes = Color.FromArgb(64, 64, 64);
                bgMenu = Color.FromArgb(55, 55, 55);
                fgMenuText = SystemColors.Control; // Белый текст для меню
                bgMenuItems = Color.FromArgb(64, 64, 64);
                fgMenuItems = SystemColors.Control;
            }
            else // Светлая тема
            {
                this.BackColor = SystemColors.Control;
                fgTextboxes = SystemColors.ControlText; // Черный текст
                bgTextboxes = SystemColors.Window;
                bgMenu = SystemColors.ControlLight; // Светлый фон для меню
                fgMenuText = SystemColors.ControlText;
                bgMenuItems = SystemColors.Window;
                fgMenuItems = SystemColors.ControlText;
            }

            // Применяем цвета
            txtCommand.ForeColor = fgTextboxes;
            txtCommand.BackColor = bgTextboxes;
            rtbLogs.ForeColor = fgTextboxes;
            rtbLogs.BackColor = bgTextboxes;

            menuStrip1.BackColor = bgMenu;
            menuStrip1.ForeColor = fgMenuText; // Для текста на самом MenuStrip, если есть

            foreach (ToolStripMenuItem item in menuStrip1.Items)
            {
                item.ForeColor = fgMenuText; // Для главных пунктов меню
                item.BackColor = bgMenu;     // Фон главных пунктов меню
                foreach (ToolStripItem dropDownItem in item.DropDownItems)
                {
                    if (dropDownItem is ToolStripMenuItem tsMenuItem)
                    {
                        tsMenuItem.ForeColor = fgMenuItems;
                        tsMenuItem.BackColor = bgMenuItems;
                    }
                }
            }
        }
        #endregion
    }

    // Вспомогательный класс для хранения информации о текущем игроке
    public class CurrentPlayerInfo
    {
        public int PlayerID { get; set; }
        public required string Nickname { get; set; }
        public int? ActivePrivilegeID { get; set; }
        public string? PrivilegeName { get; set; }
        public string? PrivilegeType { get; set; }
        public DateTime RegistrationDate { get; set; }
        public bool IsBanned { get; set; }
        public bool IsMuted { get; set; }
    }
}