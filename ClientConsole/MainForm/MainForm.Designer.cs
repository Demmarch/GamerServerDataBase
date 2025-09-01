namespace MainForm
{
    partial class MainForm
    {
        /// <summary>
        ///  Required designer variable.
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        ///  Clean up any resources being used.
        /// </summary>
        /// <param name="disposing">true if managed resources should be disposed; otherwise, false.</param>
        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
            {
                components.Dispose();
            }
            base.Dispose(disposing);
        }

        #region Windows Form Designer generated code

        /// <summary>
        ///  Required method for Designer support - do not modify
        ///  the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent()
        {
            txtCommand = new TextBox();
            rtbLogs = new RichTextBox();
            menuStrip1 = new MenuStrip();
            menuItemThemes = new ToolStripMenuItem();
            themeDark = new ToolStripMenuItem();
            themeLight = new ToolStripMenuItem();
            menuStrip1.SuspendLayout();
            SuspendLayout();
            // 
            // txtCommand
            // 
            txtCommand.BackColor = Color.FromArgb(64, 64, 64);
            txtCommand.Dock = DockStyle.Bottom;
            txtCommand.Font = new Font("Segoe UI", 12F, FontStyle.Regular, GraphicsUnit.Point, 204);
            txtCommand.ForeColor = SystemColors.Window;
            txtCommand.Location = new Point(0, 416);
            txtCommand.Name = "txtCommand";
            txtCommand.Size = new Size(800, 34);
            txtCommand.TabIndex = 0;
            txtCommand.KeyDown += txtCommand_KeyDown;
            // 
            // rtbLogs
            // 
            rtbLogs.BackColor = Color.FromArgb(64, 64, 64);
            rtbLogs.Dock = DockStyle.Fill;
            rtbLogs.ForeColor = SystemColors.Window;
            rtbLogs.Location = new Point(0, 28);
            rtbLogs.Name = "rtbLogs";
            rtbLogs.ScrollBars = RichTextBoxScrollBars.ForcedBoth;
            rtbLogs.Size = new Size(800, 388);
            rtbLogs.TabIndex = 1;
            rtbLogs.Text = "";
            // 
            // menuStrip1
            // 
            menuStrip1.BackColor = Color.FromArgb(55, 55, 55);
            menuStrip1.ImageScalingSize = new Size(20, 20);
            menuStrip1.Items.AddRange(new ToolStripItem[] { menuItemThemes });
            menuStrip1.Location = new Point(0, 0);
            menuStrip1.Name = "menuStrip1";
            menuStrip1.Size = new Size(800, 28);
            menuStrip1.TabIndex = 2;
            menuStrip1.Text = "menuStrip1";
            // 
            // menuItemThemes
            // 
            menuItemThemes.BackColor = Color.FromArgb(64, 64, 64);
            menuItemThemes.DropDownItems.AddRange(new ToolStripItem[] { themeDark, themeLight });
            menuItemThemes.ForeColor = SystemColors.Control;
            menuItemThemes.Name = "menuItemThemes";
            menuItemThemes.Size = new Size(61, 24);
            menuItemThemes.Text = "Темы";
            // 
            // themeDark
            // 
            themeDark.BackColor = Color.FromArgb(64, 64, 64);
            themeDark.ForeColor = SystemColors.Control;
            themeDark.Name = "themeDark";
            themeDark.Size = new Size(147, 26);
            themeDark.Text = "Тёмная";
            themeDark.Click += themeDark_Click;
            // 
            // themeLight
            // 
            themeLight.BackColor = Color.FromArgb(64, 64, 64);
            themeLight.ForeColor = SystemColors.Control;
            themeLight.Name = "themeLight";
            themeLight.Size = new Size(147, 26);
            themeLight.Text = "Светлая";
            themeLight.Click += themeLight_Click;
            // 
            // MainForm
            // 
            AutoScaleDimensions = new SizeF(8F, 20F);
            AutoScaleMode = AutoScaleMode.Font;
            ClientSize = new Size(800, 450);
            Controls.Add(rtbLogs);
            Controls.Add(txtCommand);
            Controls.Add(menuStrip1);
            MainMenuStrip = menuStrip1;
            Name = "MainForm";
            Text = "Клиентская консоль игрового сервера";
            menuStrip1.ResumeLayout(false);
            menuStrip1.PerformLayout();
            ResumeLayout(false);
            PerformLayout();
        }

        #endregion

        private TextBox txtCommand;
        private RichTextBox rtbLogs;
        private MenuStrip menuStrip1;
        private ToolStripMenuItem menuItemThemes;
        private ToolStripMenuItem themeDark;
        private ToolStripMenuItem themeLight;
    }
}
