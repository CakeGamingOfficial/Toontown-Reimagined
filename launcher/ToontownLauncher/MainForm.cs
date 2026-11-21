using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

namespace ToontownLauncher
{
    sealed class MainForm : Form
    {
        static readonly Color Outline = Color.FromArgb(18, 38, 74);
        static readonly Color Yellow = Color.FromArgb(255, 208, 0);
        static readonly Color Green = Color.FromArgb(40, 209, 56);
        static readonly Color GreenDark = Color.FromArgb(14, 120, 30);
        static readonly Color Blue = Color.FromArgb(30, 144, 255);
        static readonly Color Red = Color.FromArgb(240, 45, 45);
        static readonly Color DockBlue = Color.FromArgb(20, 90, 176);
        static readonly Color Inset = Color.FromArgb(234, 246, 255);
        static readonly Color SkyTop = Color.FromArgb(124, 224, 255);
        static readonly Color SkyMid = Color.FromArgb(42, 164, 244);
        static readonly Color SkyBot = Color.FromArgb(13, 75, 156);

        readonly string _baseDir;
        readonly string _configPath;
        readonly LauncherConfig _config;
        readonly Image _logo;
        readonly Font _display;
        readonly Font _ui;
        readonly Font _uiBold;
        readonly Font _uiSm;
        readonly string[] _badges;
        readonly string[] _dates;
        readonly string[] _titles;
        readonly string[] _subs;
        readonly Color[] _bannerTop;
        readonly Color[] _bannerBot;
        readonly ToonButton[] _dots;

        Label _synced;
        Label _releaseCaption;
        Label _releaseName;
        Label _badge;
        Label _date;
        Banner _banner;
        ToonButton _prev;
        ToonButton _next;
        Label _modeBody;
        Label _addressLabel;
        TextBox _addressBox;
        Label _portLabel;
        TextBox _portBox;
        ToonButton _soloTab;
        ToonButton _hostTab;
        ToonButton _joinTab;
        Label _patchStatus;
        Label _patchPercent;
        PatchBar _bar;
        ToonButton _play;
        ToonButton[] _lock;
        Panel _dim;
        RoundPanel _settings;
        TextBox _settingsPort;
        Label _settingsNote;
        ToonButton _winWindowed;
        ToonButton _winBorder;
        ToonButton _winFull;
        ToonButton _resPrev;
        ToonButton _resNext;
        Label _resValue;
        ToonButton _channelMain;
        ToonButton _channelExperimental;
        string _windowMode = "windowed";
        string _branchChoice = "main";
        List<Size> _resolutions;
        int _resIndex;
        RoundPanel _credits;
        RoundPanel _notesCard;
        Label _notesTitle;
        TextBox _notesBox;
        string _mode = "solo";
        string _remoteTag;
        string _remoteName;
        string _remotePage;
        string _remoteNotes;
        bool _busy;
        bool _playLocal;
        bool _dragging;
        Point _drag;
        int _slide;
        CancellationTokenSource _cancel;
        System.Windows.Forms.Timer _handOff;
        System.Windows.Forms.Timer _slides;
        System.Windows.Forms.Timer _stripes;
        int _handOffTries;
        int _seenAt;
        static PrivateFontCollection _fonts;
        static GCHandle _fontPin;
        static byte[] _fontBytes;

        public MainForm()
        {
            _baseDir = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\', '/');
            _configPath = Path.Combine(_baseDir, "launcher.json");
            _config = LauncherConfig.Load(_configPath);
            DisplayFile.ReadInto(_config);
            PlaceLegacyGame();
            _logo = CropLogo(LoadImage("logo.png"));
            var family = LoadFamily();
            _display = new Font(family, 22f, FontStyle.Bold, GraphicsUnit.Pixel);
            _ui = new Font("Segoe UI", 14f, FontStyle.Regular, GraphicsUnit.Pixel);
            _uiBold = new Font("Segoe UI", 14f, FontStyle.Bold, GraphicsUnit.Pixel);
            _uiSm = new Font("Segoe UI", 12f, FontStyle.Bold, GraphicsUnit.Pixel);
            _badges = new[] { "Release", "Play Together", "Packs" };
            _dates = new[] { "This computer", "Host and Join", "game folder" };
            _titles = new[] { "Toontown Reimagined", "Host a game, then your friend joins.", "Every .pck in the game folder is loaded." };
            _subs = new[] {
                "Play checks GitHub, then starts Toontown.exe.",
                "Your friend types one of your addresses and the same port. 127.0.0.1 is this computer only.",
                "Toontown.pck is required. Toontown.exe is never replaced."
            };
            _bannerTop = new[] { Color.FromArgb(40, 168, 255), Color.FromArgb(107, 70, 193), Color.FromArgb(13, 148, 136) };
            _bannerBot = new[] { Color.FromArgb(184, 240, 255), Color.FromArgb(233, 216, 253), Color.FromArgb(204, 251, 241) };
            _dots = new ToonButton[3];

            Text = "Toontown Reimagined";
            FormBorderStyle = FormBorderStyle.None;
            StartPosition = FormStartPosition.CenterScreen;
            ClientSize = new Size(1024, 760);
            BackColor = SkyMid;
            Font = _ui;
            DoubleBuffered = true;
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);

            var iconStream = Assembly.GetExecutingAssembly().GetManifestResourceStream("logo.ico");
            if (iconStream != null)
            {
                using (iconStream)
                    Icon = new Icon(iconStream);
            }
            Build();
            ClearPartials();
            ApplyMode();
            ApplySlide();
            ShowVersion();
            _slides = new System.Windows.Forms.Timer();
            _slides.Interval = 7000;
            _slides.Tick += delegate { SetSlide(_slide + 1); };
            _slides.Start();
            _stripes = new System.Windows.Forms.Timer();
            _stripes.Interval = 40;
            _stripes.Tick += delegate { if (_bar != null) _bar.Nudge(); };
            _stripes.Start();
        }

        protected override void OnShown(EventArgs e)
        {
            base.OnShown(e);
            BeginCheckVersion();
        }

        protected override void OnPaintBackground(PaintEventArgs e)
        {
            var rect = ClientRectangle;
            using (var brush = new LinearGradientBrush(rect, SkyTop, SkyBot, 90f))
            {
                var blend = new ColorBlend();
                blend.Colors = new[] { SkyTop, SkyMid, SkyBot };
                blend.Positions = new[] { 0f, 0.45f, 1f };
                brush.InterpolationColors = blend;
                e.Graphics.FillRectangle(brush, rect);
            }
            using (var cloud = new SolidBrush(Color.FromArgb(210, 255, 255, 255)))
            {
                e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
                e.Graphics.FillEllipse(cloud, 28, 18, 150, 58);
                e.Graphics.FillEllipse(cloud, 70, 4, 120, 70);
                e.Graphics.FillEllipse(cloud, 130, 22, 100, 50);
                e.Graphics.FillEllipse(cloud, 760, 680, 180, 64);
                e.Graphics.FillEllipse(cloud, 820, 660, 140, 78);
            }
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);
            if (_logo == null)
                return;
            var g = e.Graphics;
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            var dest = new Rectangle(48, 52, 320, 256);
            var shadow = new Rectangle(dest.X + 8, dest.Y + 12, dest.Width, dest.Height);
            using (var attributes = new ImageAttributes())
            {
                var matrix = new ColorMatrix();
                matrix.Matrix00 = 0f;
                matrix.Matrix11 = 0f;
                matrix.Matrix22 = 0f;
                matrix.Matrix33 = 0.28f;
                attributes.SetColorMatrix(matrix);
                g.DrawImage(_logo, shadow, 0, 0, _logo.Width, _logo.Height, GraphicsUnit.Pixel, attributes);
            }
            g.DrawImage(_logo, dest);
        }

        protected override void OnMouseDown(MouseEventArgs e)
        {
            if (e.Button == MouseButtons.Left && !_dim.Visible && e.Y < 320 && e.X < 400)
            {
                _dragging = true;
                _drag = e.Location;
            }
            base.OnMouseDown(e);
        }

        protected override void OnMouseMove(MouseEventArgs e)
        {
            if (_dragging && e.Button == MouseButtons.Left)
            {
                var cursor = PointToScreen(e.Location);
                Location = new Point(cursor.X - _drag.X, cursor.Y - _drag.Y);
            }
            base.OnMouseMove(e);
        }

        protected override void OnMouseUp(MouseEventArgs e)
        {
            _dragging = false;
            base.OnMouseUp(e);
        }

        protected override void OnSizeChanged(EventArgs e)
        {
            base.OnSizeChanged(e);
            using (var path = Shape.Round(new Rectangle(0, 0, Width, Height), 28))
                Region = new Region(path);
        }

        void Build()
        {
            var min = new ToonButton(_uiBold, Yellow, Outline);
            min.Text = "–";
            min.Radius = 14;
            min.SetBounds(948, 10, 28, 28);
            min.Click += delegate { WindowState = FormWindowState.Minimized; };
            var close = new ToonButton(_uiBold, Red, Color.White);
            close.Text = "×";
            close.Radius = 14;
            close.SetBounds(982, 10, 28, 28);
            close.Click += delegate { Close(); };

            var sync = new RoundPanel();
            sync.Fill = Outline;
            sync.Radius = 14;
            sync.SetBounds(16, 12, 360, 28);
            _synced = MakeLabel(_uiSm, Yellow, Outline, ContentAlignment.MiddleLeft);
            _synced.SetBounds(12, 2, 336, 24);
            _synced.Parent = sync;

            var releaseCard = new RoundPanel();
            releaseCard.Fill = Color.White;
            releaseCard.Radius = 16;
            releaseCard.SetBounds(744, 144, 248, 72);
            _releaseCaption = MakeLabel(_uiSm, Color.FromArgb(100, 116, 139), Color.White, ContentAlignment.MiddleLeft);
            _releaseCaption.Text = "MAIN";
            _releaseCaption.SetBounds(16, 8, 216, 18);
            _releaseCaption.Parent = releaseCard;
            _releaseName = MakeLabel(_display, Outline, Color.White, ContentAlignment.MiddleLeft);
            _releaseName.SetBounds(16, 28, 216, 32);
            _releaseName.Parent = releaseCard;

            var news = new RoundPanel();
            news.Fill = Color.White;
            news.Radius = 24;
            news.SetBounds(16, 324, 600, 252);
            _badge = MakeLabel(_uiSm, Color.White, Red, ContentAlignment.MiddleCenter);
            _badge.SetBounds(16, 14, 150, 24);
            _badge.Parent = news;
            _date = MakeLabel(_uiSm, Color.FromArgb(100, 116, 139), Color.White, ContentAlignment.MiddleLeft);
            _date.SetBounds(174, 14, 220, 24);
            _date.Parent = news;
            for (var i = 0; i < 3; i++)
            {
                var index = i;
                var dot = new ToonButton(_uiSm, Color.FromArgb(203, 213, 225), Outline);
                dot.Text = "";
                dot.Radius = 6;
                dot.Edge = 0f;
                dot.Click += delegate { SetSlide(index); };
                dot.Parent = news;
                _dots[i] = dot;
            }
            _banner = new Banner(_display, _uiBold);
            _banner.Radius = 16;
            _banner.SetBounds(16, 48, 568, 148);
            _banner.Parent = news;
            _prev = new ToonButton(_uiBold, Color.White, Outline);
            _prev.Text = "<";
            _prev.Radius = 14;
            _prev.SetBounds(8, 60, 28, 28);
            _prev.Parent = _banner;
            _prev.Click += delegate { SetSlide(_slide - 1); };
            _next = new ToonButton(_uiBold, Color.White, Outline);
            _next.Text = ">";
            _next.Radius = 14;
            _next.SetBounds(532, 60, 28, 28);
            _next.Parent = _banner;
            _next.Click += delegate { SetSlide(_slide + 1); };
            var newsFoot = MakeLabel(_uiSm, Outline, Color.White, ContentAlignment.MiddleLeft);
            newsFoot.Text = "Main uses the latest full release. Experimental uses the newest pre-release.";
            newsFoot.SetBounds(16, 206, 568, 36);
            newsFoot.Parent = news;

            var mode = new RoundPanel();
            mode.Fill = Color.White;
            mode.Radius = 24;
            mode.SetBounds(628, 324, 380, 252);
            var modeTitle = MakeLabel(_display, Outline, Color.White, ContentAlignment.MiddleLeft);
            modeTitle.Text = "Session";
            modeTitle.SetBounds(16, 10, 200, 32);
            modeTitle.Parent = mode;
            _soloTab = MakeTab("Solo");
            _hostTab = MakeTab("Host");
            _joinTab = MakeTab("Join");
            _soloTab.SetBounds(16, 48, 110, 34);
            _hostTab.SetBounds(134, 48, 110, 34);
            _joinTab.SetBounds(252, 48, 110, 34);
            _soloTab.Parent = mode;
            _hostTab.Parent = mode;
            _joinTab.Parent = mode;
            _soloTab.Click += delegate { Choose("solo"); };
            _hostTab.Click += delegate { Choose("host"); };
            _joinTab.Click += delegate { Choose("join"); };
            var details = new RoundPanel();
            details.Fill = Inset;
            details.Radius = 14;
            details.SetBounds(16, 94, 348, 146);
            details.Parent = mode;
            _modeBody = MakeLabel(_uiBold, Outline, Inset, ContentAlignment.TopLeft);
            _modeBody.SetBounds(12, 10, 324, 160);
            _modeBody.Parent = details;
            _addressLabel = MakeLabel(_uiSm, Outline, Inset, ContentAlignment.MiddleLeft);
            _addressLabel.Text = "Address";
            _addressLabel.Parent = details;
            _addressBox = MakeBox();
            _addressBox.Text = _config.Address;
            _addressBox.Parent = details;
            _portLabel = MakeLabel(_uiSm, Outline, Inset, ContentAlignment.MiddleLeft);
            _portLabel.Text = "Port";
            _portLabel.Parent = details;
            _portBox = MakeBox();
            _portBox.Text = _config.Port.ToString();
            _portBox.Parent = details;

            var dock = new RoundPanel();
            dock.Fill = DockBlue;
            dock.Radius = 24;
            dock.SetBounds(16, 592, 992, 104);
            _patchStatus = MakeLabel(_uiBold, Color.White, DockBlue, ContentAlignment.MiddleLeft);
            _patchStatus.SetBounds(18, 12, 680, 24);
            _patchStatus.Parent = dock;
            _patchPercent = MakeLabel(_display, Yellow, DockBlue, ContentAlignment.MiddleRight);
            _patchPercent.SetBounds(620, 8, 90, 30);
            _patchPercent.Parent = dock;
            _bar = new PatchBar(_uiSm);
            _bar.SetBounds(18, 44, 690, 28);
            _bar.Parent = dock;
            _play = new ToonButton(_display, Green, Color.White);
            _play.Text = "PLAY!";
            _play.Radius = 16;
            _play.Edge = 3f;
            _play.SetBounds(748, 18, 224, 68);
            _play.Parent = dock;
            _play.Click += delegate { PlayCurrent(); };

            var notes = MakeLink("Patch Notes", Color.White, Outline);
            notes.SetBounds(16, 708, 130, 36);
            notes.Click += delegate { ShowNotes(); };
            var check = MakeLink("Check Updates", Color.White, Outline);
            check.SetBounds(154, 708, 146, 36);
            check.Click += delegate { CheckForUpdates(); };
            var github = MakeLink("GitHub", Color.FromArgb(30, 41, 59), Color.White);
            github.SetBounds(308, 708, 100, 36);
            github.Click += delegate { OpenPage("https://github.com/CakeGamingOfficial/Toontown-Reimagined/releases"); };
            var settings = MakeLink("Settings", Yellow, Outline);
            settings.SetBounds(760, 708, 110, 36);
            settings.Click += delegate { ShowSettings(); };
            var credits = MakeLink("Credits", Color.White, Outline);
            credits.SetBounds(878, 708, 110, 36);
            credits.Click += delegate { ShowCredits(); };

            _lock = new[] { _soloTab, _hostTab, _joinTab, _play, notes, check, github, settings, credits, _prev, _next };

            _dim = new Panel();
            _dim.BackColor = Color.FromArgb(18, 38, 74);
            _dim.SetBounds(0, 0, 1024, 760);
            _dim.Visible = false;
            _settings = BuildSettings();
            _credits = BuildCredits();
            _notesCard = BuildNotes();
            _settings.Parent = _dim;
            _credits.Parent = _dim;
            _notesCard.Parent = _dim;
            _notesCard.Visible = false;

            sync.Parent = this;
            releaseCard.Parent = this;
            news.Parent = this;
            mode.Parent = this;
            dock.Parent = this;
            notes.Parent = this;
            check.Parent = this;
            github.Parent = this;
            settings.Parent = this;
            credits.Parent = this;
            min.Parent = this;
            close.Parent = this;
            _dim.Parent = this;
        }

        RoundPanel BuildSettings()
        {
            var card = new RoundPanel();
            card.Fill = Color.White;
            card.Radius = 22;
            card.SetBounds(232, 122, 560, 516);
            var title = MakeLabel(_display, Outline, Color.White, ContentAlignment.MiddleLeft);
            title.Text = "Settings";
            title.SetBounds(24, 18, 400, 34);
            title.Parent = card;
            var close = new ToonButton(_uiBold, Red, Color.White);
            close.Text = "×";
            close.Radius = 14;
            close.SetBounds(508, 18, 28, 28);
            close.Parent = card;
            close.Click += delegate { HideOverlays(); };
            var channelLabel = MakeLabel(_uiBold, Outline, Color.White, ContentAlignment.MiddleLeft);
            channelLabel.Text = "Play";
            channelLabel.SetBounds(24, 64, 200, 22);
            channelLabel.Parent = card;
            _channelMain = MakeTab("Main");
            _channelExperimental = MakeTab("Experimental");
            _channelMain.SetBounds(24, 90, 248, 36);
            _channelExperimental.SetBounds(284, 90, 248, 36);
            _channelMain.Parent = card;
            _channelExperimental.Parent = card;
            _channelMain.Click += delegate { ChooseChannel("main"); };
            _channelExperimental.Click += delegate { ChooseChannel("experimental"); };
            var windowLabel = MakeLabel(_uiBold, Outline, Color.White, ContentAlignment.MiddleLeft);
            windowLabel.Text = "Window";
            windowLabel.SetBounds(24, 142, 200, 22);
            windowLabel.Parent = card;
            _winWindowed = MakeTab("Windowed");
            _winBorder = MakeTab("Borderless");
            _winFull = MakeTab("Fullscreen");
            _winWindowed.SetBounds(24, 168, 163, 36);
            _winBorder.SetBounds(199, 168, 163, 36);
            _winFull.SetBounds(374, 168, 163, 36);
            _winWindowed.Parent = card;
            _winBorder.Parent = card;
            _winFull.Parent = card;
            _winWindowed.Click += delegate { ChooseWindow("windowed"); };
            _winBorder.Click += delegate { ChooseWindow("borderless"); };
            _winFull.Click += delegate { ChooseWindow("fullscreen"); };
            var sizeLabel = MakeLabel(_uiBold, Outline, Color.White, ContentAlignment.MiddleLeft);
            sizeLabel.Text = "Resolution";
            sizeLabel.SetBounds(24, 220, 200, 22);
            sizeLabel.Parent = card;
            _resPrev = new ToonButton(_uiBold, Color.White, Outline);
            _resPrev.Text = "<";
            _resPrev.Radius = 14;
            _resPrev.SetBounds(24, 246, 36, 36);
            _resPrev.Parent = card;
            _resPrev.Click += delegate { StepResolution(-1); };
            _resValue = MakeLabel(_uiBold, Outline, Color.White, ContentAlignment.MiddleCenter);
            _resValue.Text = "Current window";
            _resValue.SetBounds(68, 246, 424, 36);
            _resValue.Parent = card;
            _resNext = new ToonButton(_uiBold, Color.White, Outline);
            _resNext.Text = ">";
            _resNext.Radius = 14;
            _resNext.SetBounds(500, 246, 36, 36);
            _resNext.Parent = card;
            _resNext.Click += delegate { StepResolution(1); };
            var portLabel = MakeLabel(_uiBold, Outline, Color.White, ContentAlignment.MiddleLeft);
            portLabel.Text = "Port";
            portLabel.SetBounds(24, 298, 200, 22);
            portLabel.Parent = card;
            _settingsPort = MakeBox();
            _settingsPort.SetBounds(24, 324, 160, 32);
            _settingsPort.Parent = card;
            _settingsNote = MakeLabel(_ui, Outline, Color.White, ContentAlignment.TopLeft);
            _settingsNote.Text = "Main downloads the latest full release. Experimental downloads the newest pre-release. Host and Join use this UDP port. The game default is 4343.";
            _settingsNote.SetBounds(24, 368, 512, 72);
            _settingsNote.Parent = card;
            var cancel = MakeLink("Cancel", Color.FromArgb(226, 232, 240), Outline);
            cancel.SetBounds(304, 448, 110, 36);
            cancel.Parent = card;
            cancel.Click += delegate { HideOverlays(); };
            var save = MakeLink("Save", Green, Color.White);
            save.SetBounds(426, 448, 110, 36);
            save.Parent = card;
            save.Click += delegate { SaveSettings(); };
            return card;
        }

        RoundPanel BuildCredits()
        {
            var card = new RoundPanel();
            card.Fill = Color.White;
            card.Radius = 22;
            card.SetBounds(262, 220, 500, 300);
            var title = MakeLabel(_display, Outline, Color.White, ContentAlignment.MiddleCenter);
            title.Text = "Toontown Reimagined";
            title.SetBounds(20, 18, 460, 36);
            title.Parent = card;
            var body = MakeLabel(_ui, Outline, Color.White, ContentAlignment.TopCenter);
            body.Text = "Built in Godot.\nPacks come from GitHub Releases.\n\nA fan-made tribute inspired by Disney's Toontown Online.\nNot affiliated with The Walt Disney Company.";
            body.SetBounds(24, 70, 452, 150);
            body.Parent = card;
            var done = MakeLink("Close", Green, Color.White);
            done.SetBounds(190, 236, 120, 40);
            done.Parent = card;
            done.Click += delegate { HideOverlays(); };
            return card;
        }

        RoundPanel BuildNotes()
        {
            var card = new RoundPanel();
            card.Fill = Color.White;
            card.Radius = 22;
            card.SetBounds(192, 130, 640, 480);
            _notesTitle = MakeLabel(_display, Outline, Color.White, ContentAlignment.MiddleLeft);
            _notesTitle.Text = "Patch Notes";
            _notesTitle.SetBounds(20, 16, 520, 36);
            _notesTitle.Parent = card;
            var close = new ToonButton(_uiBold, Red, Color.White);
            close.Text = "×";
            close.Radius = 14;
            close.SetBounds(592, 16, 28, 28);
            close.Parent = card;
            close.Click += delegate { HideOverlays(); };
            _notesBox = new TextBox();
            _notesBox.Multiline = true;
            _notesBox.ReadOnly = true;
            _notesBox.ScrollBars = ScrollBars.Vertical;
            _notesBox.BorderStyle = BorderStyle.None;
            _notesBox.Font = _ui;
            _notesBox.ForeColor = Outline;
            _notesBox.BackColor = Inset;
            _notesBox.SetBounds(24, 64, 592, 340);
            _notesBox.Parent = card;
            var github = MakeLink("GitHub", Color.FromArgb(30, 41, 59), Color.White);
            github.SetBounds(380, 420, 110, 36);
            github.Parent = card;
            github.Click += delegate { OpenReleasePage(); };
            var done = MakeLink("Close", Green, Color.White);
            done.SetBounds(502, 420, 110, 36);
            done.Parent = card;
            done.Click += delegate { HideOverlays(); };
            return card;
        }

        ToonButton MakeTab(string caption)
        {
            var button = new ToonButton(_uiBold, Color.FromArgb(226, 232, 240), Outline);
            button.Text = caption;
            button.Radius = 12;
            return button;
        }

        ToonButton MakeLink(string caption, Color fill, Color text)
        {
            var button = new ToonButton(_uiBold, fill, text);
            button.Text = caption;
            button.Radius = 12;
            return button;
        }

        Label MakeLabel(Font font, Color color, Color back, ContentAlignment align)
        {
            var label = new Label();
            label.Font = font;
            label.ForeColor = color;
            label.BackColor = back;
            label.TextAlign = align;
            label.AutoSize = false;
            return label;
        }

        TextBox MakeBox()
        {
            var box = new TextBox();
            box.Font = _uiBold;
            box.ForeColor = Outline;
            box.BackColor = Color.White;
            box.BorderStyle = BorderStyle.FixedSingle;
            return box;
        }

        void Choose(string mode)
        {
            if (_busy)
                return;
            _mode = mode;
            ApplyMode();
        }

        void ApplyMode()
        {
            PaintTab(_soloTab, _mode == "solo");
            PaintTab(_hostTab, _mode == "host");
            PaintTab(_joinTab, _mode == "join");
            _modeBody.Visible = _mode != "join";
            _addressLabel.Visible = _mode == "join";
            _addressBox.Visible = _mode == "join";
            _portLabel.Visible = _mode != "solo";
            _portBox.Visible = _mode != "solo";
            if (_mode == "solo")
            {
                _modeBody.Text = "Play on this computer.";
                _modeBody.SetBounds(12, 16, 324, 114);
            }
            else if (_mode == "host")
            {
                var lines = LanLines();
                var listed = lines.Length == 0 ? "No local address was found." : string.Join("\n", lines);
                _modeBody.Text = "Friends join one of these addresses.\n" + listed + "\nOn this computer, use 127.0.0.1.";
                _modeBody.SetBounds(12, 8, 324, 88);
                _portLabel.SetBounds(12, 102, 70, 28);
                _portBox.SetBounds(84, 102, 120, 28);
            }
            else
            {
                _addressLabel.SetBounds(12, 12, 320, 20);
                _addressBox.SetBounds(12, 34, 320, 28);
                _portLabel.SetBounds(12, 78, 70, 28);
                _portBox.SetBounds(84, 76, 120, 28);
            }
        }

        void PaintTab(ToonButton button, bool on)
        {
            button.Fill = on ? Blue : Color.FromArgb(226, 232, 240);
            button.ForeColor = on ? Color.White : Outline;
            button.Invalidate();
        }

        void SetSlide(int index)
        {
            var count = _titles.Length;
            _slide = ((index % count) + count) % count;
            ApplySlide();
        }

        void ApplySlide()
        {
            _badge.Text = _badges[_slide];
            _badge.BackColor = _slide == 1 ? Color.FromArgb(147, 51, 234) : _slide == 2 ? GreenDark : Red;
            _date.Text = _dates[_slide];
            _banner.Title = _titles[_slide];
            _banner.Subtitle = _subs[_slide];
            _banner.Fill = _bannerTop[_slide];
            _banner.Fill2 = _bannerBot[_slide];
            _banner.Invalidate();
            var x = 568;
            for (var i = 2; i >= 0; i--)
            {
                var w = i == _slide ? 22 : 12;
                x -= w;
                _dots[i].Fill = i == _slide ? Blue : Color.FromArgb(203, 213, 225);
                _dots[i].SetBounds(x, 20, w, 12);
                _dots[i].Invalidate();
                x -= 8;
            }
        }

        void RefreshReleaseSlide()
        {
            var tag = CurrentTag();
            if (string.IsNullOrEmpty(_remoteName))
                _titles[0] = string.IsNullOrEmpty(tag) ? "Toontown Reimagined" : "Release " + tag;
            else
                _titles[0] = _remoteName;
            if (!string.IsNullOrEmpty(_remoteNotes))
                _subs[0] = FirstLine(_remoteNotes);
            else if (string.IsNullOrEmpty(tag))
                _subs[0] = "Play uses the packs already in the game folder.";
            else
                _subs[0] = "GitHub release " + tag + ". Play downloads new packs before the game starts.";
            _dates[0] = string.IsNullOrEmpty(tag) ? "This computer" : tag;
            if (_slide == 0)
                ApplySlide();
        }

        async void BeginCheckVersion()
        {
            try
            {
                var info = await ReleaseClient.GetLatestAsync(PlayChannel(), CancellationToken.None);
                if (IsDisposed || info == null || string.IsNullOrEmpty(info.Tag))
                    return;
                Action apply = delegate
                {
                    if (IsDisposed)
                        return;
                    Remember(info);
                    ShowVersion();
                };
                if (InvokeRequired)
                    BeginInvoke(apply);
                else
                    apply();
            }
            catch (Exception ex)
            {
                var message = Friendly(ex);
                if (message.IndexOf("no pre-release") < 0 && message.IndexOf("no full release") < 0)
                    return;
                Action apply = delegate
                {
                    if (!IsDisposed)
                        SetPatch(message, 0, PlayChannel());
                };
                if (InvokeRequired)
                    BeginInvoke(apply);
                else
                    apply();
            }
        }

        string PlayChannel()
        {
            return ReleaseClient.IsExperimental(_config.Branch) ? "experimental" : "main";
        }

        void ShowVersion()
        {
            var tag = CurrentTag();
            var channel = PlayChannel();
            _releaseCaption.Text = channel == "experimental" ? "EXPERIMENTAL" : "MAIN";
            _synced.Text = string.IsNullOrEmpty(tag) ? "Synced: " + channel : "Synced: " + channel + " " + tag;
            _releaseName.Text = string.IsNullOrEmpty(tag) ? "Local copy" : tag;
            RefreshReleaseSlide();
            if (!_busy)
                ShowReady();
        }

        string CurrentTag()
        {
            if (!string.IsNullOrEmpty(_remoteTag))
                return _remoteTag;
            return _config.TagFor(PlayChannel());
        }

        void ShowReady()
        {
            var tag = CurrentTag();
            if (!File.Exists(GameExe()) || !File.Exists(PackPath()))
            {
                SetPatch("Add Toontown.exe under game/" + PlayChannel() + ". Packs download into that folder.", 0, "Toontown.exe is never replaced.");
                return;
            }
            if (string.IsNullOrEmpty(tag))
                SetPatch("Ready. This copy has no GitHub release recorded yet.", 100, "Toontown.pck is in the game folder.");
            else
                SetPatch("Ready. Release " + tag + ".", 100, "Toontown.pck is in the game folder.");
        }

        void SetPatch(string status, int percent, string detail)
        {
            if (percent < 0)
                percent = 0;
            if (percent > 100)
                percent = 100;
            _patchStatus.Text = status;
            _patchPercent.Text = percent + "%";
            _bar.Value = percent;
            _bar.Caption = detail ?? "";
        }

        void CheckForUpdates()
        {
            RunUpdate(false);
        }

        void PlayCurrent()
        {
            if (!FieldsOk(_mode))
                return;
            SaveFields();
            RunUpdate(true);
        }

        async void RunUpdate(bool launch)
        {
            if (_busy)
                return;
            var mode = _mode;
            if (launch && !FieldsOk(mode))
                return;
            if (launch)
                SaveFields();
            if (_playLocal)
            {
                _playLocal = false;
                if (launch)
                    Launch(mode);
                return;
            }
            EnsureExe();
            if (!File.Exists(GameExe()))
            {
                SetPatch("game/" + PlayChannel() + "/Toontown.exe was not found. Play does not download or replace that file.", 0, "");
                return;
            }
            _busy = true;
            SetBusy(true);
            SetPlayBusy(true);
            if (_cancel != null)
                _cancel.Dispose();
            _cancel = new CancellationTokenSource();
            try
            {
                SetPatch("Checking GitHub for a newer release...", 8, "");
                var info = await ReleaseClient.GetLatestAsync(PlayChannel(), _cancel.Token);
                Remember(info);
                ShowVersion();
                var needed = PacksToDownload(info);
                if (needed.Count == 0)
                {
                    RememberInstalled(info.Tag);
                    SetPatch("Up to date (" + info.Tag + ").", 100, "Toontown.pck matches this release.");
                    FinishUpdate(launch, mode);
                    return;
                }
                for (var i = 0; i < needed.Count; i++)
                {
                    var pack = needed[i];
                    var dest = Path.Combine(ChannelDir(), pack.Name);
                    var partial = dest + ".partial";
                    if (File.Exists(partial))
                        File.Delete(partial);
                    var label = pack.Name;
                    if (needed.Count > 1)
                        label = pack.Name + " (" + (i + 1) + " of " + needed.Count + ")";
                    var progress = new Progress<int>(delegate (int pct)
                    {
                        SetPatch("Downloading " + label + "...", pct, label);
                    });
                    await ReleaseClient.DownloadAsync(pack.Url, partial, pack.Name, progress, _cancel.Token);
                    PackFile.Replace(partial, dest);
                }
                RememberInstalled(info.Tag);
                ShowVersion();
                SetPatch("Updated to " + info.Tag + ".", 100, "Packs are in the game folder.");
                FinishUpdate(launch, mode);
            }
            catch (OperationCanceledException)
            {
                _busy = false;
                SetPlayBusy(false);
                SetBusy(false);
            }
            catch (Exception ex)
            {
                TryDeletePartial();
                if (NoRelease(ex) && File.Exists(GameExe()) && File.Exists(PackPath()))
                {
                    SetPatch("Up to date.", 100, "Toontown.pck is in the game folder.");
                    ShowVersion();
                    FinishUpdate(launch, mode);
                    return;
                }
                Fail(Friendly(ex));
            }
        }

        void FinishUpdate(bool launch, string mode)
        {
            _busy = false;
            SetPlayBusy(false);
            SetBusy(false);
            if (launch)
                Launch(mode);
        }

        void Launch(string mode)
        {
            EnsureExe();
            var exe = GameExe();
            if (!File.Exists(exe))
            {
                Fail("game/" + PlayChannel() + "/Toontown.exe was not found. Play does not download or replace that file.");
                return;
            }
            if (!File.Exists(PackPath()))
            {
                Fail("game/Toontown.pck was not found.");
                return;
            }
            var arguments = "";
            if (mode == "host")
                arguments = "-- --host " + _config.Port;
            else if (mode == "join")
                arguments = "-- --join " + QuoteArg(_config.Address) + " " + _config.Port;
            try { DisplayFile.Write(_config); }
            catch (Exception) { }
            if (!GameStart.Open(exe, arguments, ChannelDir()))
            {
                _busy = false;
                SetPlayBusy(false);
                SetBusy(false);
                SetPatch("The game did not start.", 0, "");
                return;
            }
            SetPatch("The game is open.", 100, "");
            BeginHandOff();
        }

        void BeginHandOff()
        {
            _handOffTries = 0;
            _seenAt = 0;
            if (_handOff == null)
            {
                _handOff = new System.Windows.Forms.Timer();
                _handOff.Interval = 200;
                _handOff.Tick += delegate { OnHandOff(); };
            }
            _handOff.Start();
        }

        void OnHandOff()
        {
            _handOffTries++;
            var hwnd = GameStart.FindGameWindow();
            if (hwnd != IntPtr.Zero)
            {
                if (_seenAt == 0)
                    _seenAt = _handOffTries;
                if (_handOffTries - _seenAt < 5)
                    return;
                GameStart.HandToGame(hwnd);
                _handOff.Stop();
                GameStart.ReopenWhenGameExits(GameStart.WindowProcessId(hwnd), Application.ExecutablePath);
                Close();
                return;
            }
            if (_handOffTries >= 75)
                _handOff.Stop();
        }

        void Fail(string message)
        {
            _busy = false;
            SetPlayBusy(false);
            SetBusy(false);
            if (File.Exists(GameExe()) && File.Exists(PackPath()))
            {
                _playLocal = true;
                SetPatch(message + " Play again to launch this copy.", 100, "Toontown.pck is already installed.");
                return;
            }
            SetPatch(message, 0, "");
        }

        static bool NoRelease(Exception ex)
        {
            var invalid = ex as InvalidOperationException;
            return invalid != null && invalid.Message == "GitHub has no release yet.";
        }

        static string Friendly(Exception ex)
        {
            var web = ex as HttpRequestException;
            if (web != null)
                return "Could not reach GitHub.";
            if (ex is WebException)
                return "Could not reach GitHub.";
            if (ex.Message != null && ex.Message.Length > 0)
                return ex.Message;
            return "The download did not finish.";
        }

        bool FieldsOk(string mode)
        {
            var port = Port();
            if (port < 1 || port > 65535)
            {
                SetPatch("Type a port from 1 to 65535.", 0, "");
                return false;
            }
            if (mode == "join" && Address().Length == 0)
            {
                SetPatch("Type the host computer's address.", 0, "");
                return false;
            }
            return true;
        }

        void SaveFields()
        {
            _config.Address = Address();
            _config.Port = Port();
            try { _config.Save(_configPath); }
            catch (Exception) { }
        }

        string Address()
        {
            return _addressBox.Text.Trim();
        }

        int Port()
        {
            int port;
            if (!int.TryParse(_portBox.Text.Trim(), out port))
                return 0;
            return port;
        }

        void SetBusy(bool busy)
        {
            foreach (var button in _lock)
                button.Enabled = !busy;
        }

        void SetPlayBusy(bool busy)
        {
            _play.Text = busy ? "UPDATING" : "PLAY!";
            _play.Fill = busy ? Yellow : Green;
            _play.ForeColor = busy ? Outline : Color.White;
            _play.Invalidate();
        }

        void ChooseChannel(string channel)
        {
            _branchChoice = ReleaseClient.IsExperimental(channel) ? "experimental" : "main";
            ApplyChannelChoice();
        }

        void ApplyChannelChoice()
        {
            var experimental = ReleaseClient.IsExperimental(_branchChoice);
            PaintTab(_channelMain, !experimental);
            PaintTab(_channelExperimental, experimental);
        }

        void RememberInstalled(string tag)
        {
            _config.SetTag(PlayChannel(), tag ?? "");
            try { _config.Save(_configPath); }
            catch (Exception) { }
        }

        void ShowSettings()
        {
            _branchChoice = PlayChannel();
            ApplyChannelChoice();
            _windowMode = _config.WindowMode;
            if (_windowMode != "windowed" && _windowMode != "borderless" && _windowMode != "fullscreen")
                _windowMode = "windowed";
            _resolutions = BuildResolutions();
            _resIndex = 0;
            for (var i = 0; i < _resolutions.Count; i++)
            {
                if (_resolutions[i].Width == _config.Width && _resolutions[i].Height == _config.Height)
                {
                    _resIndex = i;
                    break;
                }
            }
            ApplyWindowChoice();
            ShowResolution();
            _settingsPort.Text = _portBox.Text;
            _settingsNote.Text = "Main downloads the latest full release. Experimental downloads the newest pre-release. Host and Join use this UDP port. The game default is 4343.";
            _credits.Visible = false;
            _notesCard.Visible = false;
            _settings.Visible = true;
            _dim.Visible = true;
            _dim.BringToFront();
        }

        void ChooseWindow(string mode)
        {
            _windowMode = mode;
            ApplyWindowChoice();
            ShowResolution();
        }

        void ApplyWindowChoice()
        {
            PaintTab(_winWindowed, _windowMode == "windowed");
            PaintTab(_winBorder, _windowMode == "borderless");
            PaintTab(_winFull, _windowMode == "fullscreen");
        }

        void StepResolution(int delta)
        {
            if (_resolutions == null || _resolutions.Count == 0)
                return;
            _resIndex = _resIndex + delta;
            if (_resIndex < 0)
                _resIndex = _resolutions.Count - 1;
            else if (_resIndex >= _resolutions.Count)
                _resIndex = 0;
            ShowResolution();
        }

        void ShowResolution()
        {
            var size = Size.Empty;
            if (_resolutions != null && _resIndex >= 0 && _resIndex < _resolutions.Count)
                size = _resolutions[_resIndex];
            if (size.Width < 640 || size.Height < 480)
                _resValue.Text = _windowMode == "windowed" ? "Current window" : "This screen";
            else
                _resValue.Text = size.Width + " x " + size.Height;
        }

        List<Size> BuildResolutions()
        {
            var list = new List<Size>();
            list.Add(Size.Empty);
            var screen = ScreenSize();
            var widths = new[] { 640, 800, 1024, 1280, 1280, 1366, 1440, 1600, 1680, 1920, 1920, 2560, 2560, 3440, 3840 };
            var heights = new[] { 480, 600, 768, 720, 800, 768, 900, 900, 1050, 1080, 1200, 1080, 1440, 1440, 2160 };
            for (var i = 0; i < widths.Length; i++)
            {
                if (widths[i] <= screen.Width && heights[i] <= screen.Height)
                    list.Add(new Size(widths[i], heights[i]));
            }
            if (screen.Width >= 640 && screen.Height >= 480 && !HasSize(list, screen))
                list.Add(screen);
            var saved = new Size(_config.Width, _config.Height);
            if (saved.Width >= 640 && saved.Height >= 480 && !HasSize(list, saved))
                list.Add(saved);
            return list;
        }

        static bool HasSize(List<Size> list, Size size)
        {
            foreach (var item in list)
            {
                if (item.Width == size.Width && item.Height == size.Height)
                    return true;
            }
            return false;
        }

        Size ScreenSize()
        {
            var screen = IsHandleCreated ? Screen.FromControl(this) : Screen.PrimaryScreen;
            if (screen == null)
                return new Size(1920, 1080);
            return screen.Bounds.Size;
        }

        void SaveSettings()
        {
            _portBox.Text = _settingsPort.Text.Trim();
            if (Port() < 1 || Port() > 65535)
            {
                _settingsNote.Text = "Type a port from 1 to 65535.";
                return;
            }
            var size = Size.Empty;
            if (_resolutions != null && _resIndex >= 0 && _resIndex < _resolutions.Count)
                size = _resolutions[_resIndex];
            _config.WindowMode = _windowMode;
            _config.Width = size.Width < 640 || size.Height < 480 ? 0 : size.Width;
            _config.Height = size.Width < 640 || size.Height < 480 ? 0 : size.Height;
            var nextChannel = ReleaseClient.IsExperimental(_branchChoice) ? "experimental" : "main";
            var channelChanged = !string.Equals(nextChannel, PlayChannel(), StringComparison.OrdinalIgnoreCase);
            _config.Branch = nextChannel;
            SaveFields();
            if (channelChanged)
            {
                _remoteTag = "";
                _remoteName = "";
                _remotePage = "";
                _remoteNotes = "";
            }
            try
            {
                DisplayFile.Write(_config);
            }
            catch (Exception)
            {
                _settingsNote.Text = "The window settings could not be saved.";
                return;
            }
            HideOverlays();
            ShowVersion();
            if (channelChanged && !_busy)
                BeginCheckVersion();
        }

        void ShowCredits()
        {
            _settings.Visible = false;
            _notesCard.Visible = false;
            _credits.Visible = true;
            _dim.Visible = true;
            _dim.BringToFront();
        }

        void HideOverlays()
        {
            _dim.Visible = false;
        }

        void ShowNotes()
        {
            _settings.Visible = false;
            _credits.Visible = false;
            _notesCard.Visible = true;
            _dim.Visible = true;
            _dim.BringToFront();
            if (string.IsNullOrEmpty(_remoteNotes))
            {
                _notesTitle.Text = "Patch Notes";
                _notesBox.Text = "Loading patch notes...";
                LoadNotes();
                return;
            }
            FillNotes();
        }

        async void LoadNotes()
        {
            try
            {
                var info = await ReleaseClient.GetLatestAsync(PlayChannel(), CancellationToken.None);
                if (IsDisposed || info == null)
                    return;
                Action apply = delegate
                {
                    if (IsDisposed)
                        return;
                    Remember(info);
                    ShowVersion();
                    FillNotes();
                };
                if (InvokeRequired)
                    BeginInvoke(apply);
                else
                    apply();
            }
            catch (Exception)
            {
                Action apply = delegate
                {
                    if (!IsDisposed)
                        _notesBox.Text = "Patch notes could not be loaded.";
                };
                if (InvokeRequired)
                    BeginInvoke(apply);
                else
                    apply();
            }
        }

        void FillNotes()
        {
            var tag = CurrentTag();
            var name = _remoteName;
            if (string.IsNullOrEmpty(name))
                _notesTitle.Text = string.IsNullOrEmpty(tag) ? "Patch Notes" : "Patch Notes — " + tag;
            else
                _notesTitle.Text = name;
            if (string.IsNullOrEmpty(_remoteNotes))
                _notesBox.Text = "This release has no patch notes yet.";
            else
                _notesBox.Text = _remoteNotes;
        }

        void Remember(ReleaseInfo info)
        {
            if (info == null)
                return;
            _remoteTag = info.Tag;
            _remoteName = info.Name;
            _remotePage = info.Page;
            _remoteNotes = info.Body;
        }

        static string FirstLine(string text)
        {
            var line = text.Replace("\r", "");
            var cut = line.IndexOf('\n');
            if (cut >= 0)
                line = line.Substring(0, cut);
            line = line.Trim();
            if (line.Length > 140)
                line = line.Substring(0, 137) + "...";
            return line;
        }

        void OpenReleasePage()
        {
            if (!string.IsNullOrEmpty(_remotePage))
                OpenPage(_remotePage);
            else
                OpenPage("https://github.com/CakeGamingOfficial/Toontown-Reimagined/releases");
        }

        static void OpenPage(string url)
        {
            Process.Start(url);
        }

        string ChannelDir()
        {
            var dir = Path.Combine(_baseDir, "game", PlayChannel());
            if (!Directory.Exists(dir))
                Directory.CreateDirectory(dir);
            return dir;
        }

        string GameExe()
        {
            return Path.Combine(ChannelDir(), "Toontown.exe");
        }

        string PackPath()
        {
            return Path.Combine(ChannelDir(), "Toontown.pck");
        }

        void PlaceLegacyGame()
        {
            var root = Path.Combine(_baseDir, "game");
            var legacyPack = Path.Combine(root, "Toontown.pck");
            var legacyExe = Path.Combine(root, "Toontown.exe");
            if (!File.Exists(legacyPack) && !File.Exists(legacyExe))
                return;
            var channel = ReleaseClient.IsExperimental(_config.InstalledBranch) ? "experimental" : "main";
            if (string.IsNullOrEmpty(_config.TagFor(channel)) && !string.IsNullOrEmpty(_config.Release))
                _config.SetTag(channel, _config.Release);
            var destDir = Path.Combine(root, channel);
            if (!Directory.Exists(destDir))
                Directory.CreateDirectory(destDir);
            var moved = MoveIfAbsent(legacyExe, Path.Combine(destDir, "Toontown.exe"));
            if (Directory.Exists(root))
            {
                foreach (var pack in Directory.GetFiles(root, "*.pck"))
                {
                    if (MoveIfAbsent(pack, Path.Combine(destDir, Path.GetFileName(pack))))
                        moved = true;
                }
            }
            if (moved)
            {
                try { _config.Save(_configPath); }
                catch (Exception) { }
            }
        }

        void EnsureExe()
        {
            var dest = Path.Combine(ChannelDir(), "Toontown.exe");
            if (File.Exists(dest))
                return;
            var root = Path.Combine(_baseDir, "game");
            var sources = new[]
            {
                Path.Combine(root, "Toontown.exe"),
                Path.Combine(root, "main", "Toontown.exe"),
                Path.Combine(root, "experimental", "Toontown.exe")
            };
            foreach (var source in sources)
            {
                if (!File.Exists(source) || string.Equals(source, dest, StringComparison.OrdinalIgnoreCase))
                    continue;
                File.Copy(source, dest);
                return;
            }
        }

        static bool MoveIfAbsent(string source, string dest)
        {
            if (!File.Exists(source) || File.Exists(dest))
                return false;
            File.Move(source, dest);
            return true;
        }

        System.Collections.Generic.List<ReleasePack> PacksToDownload(ReleaseInfo info)
        {
            var needed = new System.Collections.Generic.List<ReleasePack>();
            var saved = _config.TagFor(PlayChannel());
            var sameRelease = saved.Length > 0 && saved == info.Tag;
            foreach (var pack in info.Packs)
            {
                var dest = Path.Combine(ChannelDir(), pack.Name);
                if (!sameRelease || !File.Exists(dest))
                    needed.Add(pack);
            }
            return needed;
        }

        void ClearPartials()
        {
            var dir = ChannelDir();
            if (!Directory.Exists(dir))
                return;
            foreach (var partial in Directory.GetFiles(dir, "*.partial"))
            {
                if (!partial.EndsWith(".pck.partial", StringComparison.OrdinalIgnoreCase))
                    continue;
                try { File.Delete(partial); }
                catch (Exception) { }
            }
        }

        void TryDeletePartial()
        {
            ClearPartials();
        }

        static string QuoteArg(string text)
        {
            if (text.IndexOf(' ') < 0 && text.IndexOf('"') < 0)
                return text;
            return "\"" + text.Replace("\"", "") + "\"";
        }

        static string[] LanLines()
        {
            var lines = new System.Collections.Generic.List<string>();
            foreach (var nic in NetworkInterface.GetAllNetworkInterfaces())
            {
                if (nic.OperationalStatus != OperationalStatus.Up)
                    continue;
                foreach (var uni in nic.GetIPProperties().UnicastAddresses)
                {
                    if (uni.Address.AddressFamily != AddressFamily.InterNetwork)
                        continue;
                    var address = uni.Address.ToString();
                    if (address == "127.0.0.1" || address.StartsWith("169.254."))
                        continue;
                    if (!lines.Contains(address))
                        lines.Add(address);
                }
            }
            return lines.ToArray();
        }

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            if (_cancel != null)
                _cancel.Cancel();
            if (_handOff != null)
                _handOff.Stop();
            if (_slides != null)
                _slides.Stop();
            if (_stripes != null)
                _stripes.Stop();
            base.OnFormClosing(e);
        }

        static Image LoadImage(string name)
        {
            var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream(name);
            if (stream == null)
                return null;
            using (stream)
            using (var image = Image.FromStream(stream))
                return new Bitmap(image);
        }

        static Image CropLogo(Image source)
        {
            if (source == null)
                return null;
            var crop = new Rectangle(28, 86, 978, 782);
            if (crop.Right > source.Width || crop.Bottom > source.Height)
                return source;
            var bitmap = new Bitmap(crop.Width, crop.Height);
            using (var graphics = Graphics.FromImage(bitmap))
            {
                graphics.DrawImage(source, new Rectangle(0, 0, crop.Width, crop.Height), crop, GraphicsUnit.Pixel);
            }
            source.Dispose();
            return bitmap;
        }

        static FontFamily LoadFamily()
        {
            var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("ImpressBT.ttf");
            if (stream == null)
                return FontFamily.GenericSansSerif;
            using (stream)
            {
                _fontBytes = new byte[stream.Length];
                stream.Read(_fontBytes, 0, _fontBytes.Length);
            }
            _fontPin = GCHandle.Alloc(_fontBytes, GCHandleType.Pinned);
            _fonts = new PrivateFontCollection();
            _fonts.AddMemoryFont(_fontPin.AddrOfPinnedObject(), _fontBytes.Length);
            if (_fonts.Families.Length == 0)
                return FontFamily.GenericSansSerif;
            return _fonts.Families[0];
        }
    }

    static class Shape
    {
        public static GraphicsPath Round(Rectangle bounds, int radius)
        {
            var path = new GraphicsPath();
            var limit = Math.Min(bounds.Width, bounds.Height) / 2;
            var r = radius;
            if (r > limit)
                r = limit;
            var d = r * 2;
            if (d < 2)
            {
                path.AddRectangle(bounds);
                return path;
            }
            path.AddArc(bounds.Left, bounds.Top, d, d, 180, 90);
            path.AddArc(bounds.Right - d, bounds.Top, d, d, 270, 90);
            path.AddArc(bounds.Right - d, bounds.Bottom - d, d, d, 0, 90);
            path.AddArc(bounds.Left, bounds.Bottom - d, d, d, 90, 90);
            path.CloseFigure();
            return path;
        }
    }

    class RoundPanel : Panel
    {
        public Color Fill = Color.White;
        public Color Fill2;
        public Color Edge = Color.FromArgb(18, 38, 74);
        public int Radius = 18;
        public int Border = 3;

        public RoundPanel()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
            BackColor = Color.White;
        }

        protected override void OnSizeChanged(EventArgs e)
        {
            base.OnSizeChanged(e);
            if (Width < 2 || Height < 2)
                return;
            using (var path = Shape.Round(new Rectangle(0, 0, Width, Height), Radius))
                Region = new Region(path);
        }

        protected override void OnPaintBackground(PaintEventArgs e)
        {
        }

        public void PaintSurface(Graphics g)
        {
            var rect = new Rectangle(0, 0, Width - 1, Height - 1);
            if (rect.Width < 2 || rect.Height < 2)
                return;
            var previous = g.SmoothingMode;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            using (var path = Shape.Round(rect, Radius))
            using (var pen = new Pen(Edge, Border))
            {
                pen.Alignment = PenAlignment.Inset;
                Brush brush;
                if (Fill2.IsEmpty)
                    brush = new SolidBrush(Fill);
                else
                    brush = new LinearGradientBrush(rect, Fill, Fill2, 90f);
                using (brush)
                    g.FillPath(brush, path);
                g.DrawPath(pen, path);
            }
            g.SmoothingMode = previous;
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            PaintSurface(e.Graphics);
        }
    }

    sealed class Banner : RoundPanel
    {
        readonly Font _titleFont;
        readonly Font _subFont;
        public string Title = "";
        public string Subtitle = "";

        public Banner(Font titleFont, Font subFont)
        {
            _titleFont = titleFont;
            _subFont = subFont;
            Border = 3;
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);
            var g = e.Graphics;
            g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
            var title = new Rectangle(44, 16, Width - 88, 52);
            TextRenderer.DrawText(g, Title, _titleFont, title, Color.White, TextFormatFlags.Left | TextFormatFlags.WordBreak | TextFormatFlags.EndEllipsis);
            var sub = new Rectangle(44, 74, Width - 88, 58);
            using (var path = Shape.Round(sub, 12))
            using (var brush = new SolidBrush(Color.FromArgb(230, 255, 255, 255)))
                g.FillPath(brush, path);
            TextRenderer.DrawText(g, Subtitle, _subFont, new Rectangle(sub.X + 8, sub.Y + 6, sub.Width - 16, sub.Height - 12), Color.FromArgb(18, 38, 74), TextFormatFlags.Left | TextFormatFlags.WordBreak | TextFormatFlags.EndEllipsis);
        }
    }

    sealed class ToonButton : Control
    {
        readonly Font _font;
        public Color Fill;
        public int Radius = 12;
        public float Edge = 2f;
        bool _hot;
        bool _down;

        public ToonButton(Font font, Color fill, Color text)
        {
            _font = font;
            Fill = fill;
            ForeColor = text;
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.Opaque, true);
            Cursor = Cursors.Hand;
            Font = font;
        }

        protected override void OnPaintBackground(PaintEventArgs e)
        {
        }

        void PaintBackdrop(Graphics g)
        {
            var parent = Parent;
            if (parent == null)
            {
                g.Clear(SystemColors.Control);
                return;
            }
            g.Clear(parent.BackColor);
            var state = g.Save();
            g.TranslateTransform(-Left, -Top);
            var panel = parent as RoundPanel;
            if (panel != null)
                panel.PaintSurface(g);
            else
            {
                var args = new PaintEventArgs(g, new Rectangle(Left, Top, Width, Height));
                InvokePaintBackground(parent, args);
            }
            g.Restore(state);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics;
            PaintBackdrop(g);
            var fill = Fill;
            if (!Enabled)
                fill = Color.FromArgb(186, 196, 208);
            else if (_hot && !_down)
                fill = ControlPaint.Light(Fill, 0.12f);
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
            var shift = _down ? 1 : 0;
            var pad = Edge > 0f ? (int)Math.Ceiling(Edge / 2f) : 1;
            var rect = new Rectangle(pad, pad + shift, Math.Max(2, Width - pad * 2), Math.Max(2, Height - pad * 2 - shift));
            using (var path = Shape.Round(rect, Radius))
            using (var brush = new SolidBrush(fill))
            {
                g.FillPath(brush, path);
                if (Edge > 0f)
                {
                    using (var pen = new Pen(Color.FromArgb(18, 38, 74), Edge))
                    {
                        pen.LineJoin = LineJoin.Round;
                        g.DrawPath(pen, path);
                    }
                }
                if (rect.Width > 48 && rect.Height > 28 && Edge > 0f)
                {
                    var band = Math.Max(6, rect.Height / 3);
                    var gloss = new Rectangle(rect.X + 5, rect.Y + 3, Math.Max(2, rect.Width - 10), band);
                    var light = ControlPaint.Light(fill, 0.35f);
                    var saved = g.Save();
                    g.SetClip(path, CombineMode.Intersect);
                    using (var shine = Shape.Round(gloss, Math.Min(Radius, band / 2)))
                    using (var shineBrush = new LinearGradientBrush(gloss, light, fill, LinearGradientMode.Vertical))
                        g.FillPath(shineBrush, shine);
                    g.Restore(saved);
                }
            }
            var color = Enabled ? ForeColor : Color.FromArgb(90, 98, 112);
            if (!DrawMark(g, rect, color))
                TextRenderer.DrawText(g, Text, _font, rect, color, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis);
        }

        bool DrawMark(Graphics g, Rectangle rect, Color color)
        {
            var mark = Text;
            var chevron = mark == "<" || mark == ">";
            var dash = mark == "–" || mark == "-";
            var cross = mark == "×";
            if (!chevron && !dash && !cross)
                return false;
            var cx = rect.Left + rect.Width / 2f;
            var cy = rect.Top + rect.Height / 2f;
            using (var pen = new Pen(color, 2.25f))
            {
                pen.StartCap = LineCap.Round;
                pen.EndCap = LineCap.Round;
                pen.LineJoin = LineJoin.Round;
                if (chevron)
                {
                    var dir = mark == "<" ? 1f : -1f;
                    g.DrawLines(pen, new[]
                    {
                        new PointF(cx + dir * 3.5f, cy - 5f),
                        new PointF(cx - dir * 3.5f, cy),
                        new PointF(cx + dir * 3.5f, cy + 5f)
                    });
                }
                else if (dash)
                    g.DrawLine(pen, cx - 5f, cy, cx + 5f, cy);
                else
                {
                    g.DrawLine(pen, cx - 4.5f, cy - 4.5f, cx + 4.5f, cy + 4.5f);
                    g.DrawLine(pen, cx + 4.5f, cy - 4.5f, cx - 4.5f, cy + 4.5f);
                }
            }
            return true;
        }

        protected override void OnMouseEnter(EventArgs e)
        {
            _hot = true;
            Invalidate();
            base.OnMouseEnter(e);
        }

        protected override void OnMouseLeave(EventArgs e)
        {
            _hot = false;
            _down = false;
            Invalidate();
            base.OnMouseLeave(e);
        }

        protected override void OnMouseDown(MouseEventArgs e)
        {
            if (e.Button == MouseButtons.Left)
            {
                _down = true;
                Invalidate();
            }
            base.OnMouseDown(e);
        }

        protected override void OnMouseUp(MouseEventArgs e)
        {
            _down = false;
            Invalidate();
            base.OnMouseUp(e);
        }
    }

    sealed class PatchBar : Control
    {
        readonly Font _font;
        int _value;
        int _shift;
        string _caption = "";

        public PatchBar(Font font)
        {
            _font = font;
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
            Font = font;
        }

        protected override void OnSizeChanged(EventArgs e)
        {
            base.OnSizeChanged(e);
            if (Width < 2 || Height < 2)
                return;
            var radius = Height / 2;
            using (var path = Shape.Round(new Rectangle(0, 0, Width, Height), radius))
                Region = new Region(path);
        }

        public int Value
        {
            get { return _value; }
            set
            {
                _value = value;
                Invalidate();
            }
        }

        public string Caption
        {
            get { return _caption; }
            set
            {
                _caption = value ?? "";
                Invalidate();
            }
        }

        public void Nudge()
        {
            _shift = (_shift + 3) % 36;
            Invalidate();
        }

        protected override void OnPaintBackground(PaintEventArgs e)
        {
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
            var rect = new Rectangle(0, 0, Width - 1, Height - 1);
            using (var path = Shape.Round(rect, Height / 2))
            {
                using (var track = new SolidBrush(Color.FromArgb(18, 38, 74)))
                    g.FillPath(track, path);
                var inner = new Rectangle(3, 3, Width - 7, Height - 7);
                var fillWidth = (inner.Width * _value) / 100;
                if (fillWidth > 0)
                {
                    var fill = new Rectangle(inner.X, inner.Y, Math.Max(fillWidth, inner.Height), inner.Height);
                    if (fill.Right > inner.Right)
                        fill.Width = inner.Width;
                    g.SetClip(path);
                    using (var bar = Shape.Round(fill, Math.Max(1, inner.Height / 2)))
                    using (var brush = new SolidBrush(Color.FromArgb(40, 209, 56)))
                        g.FillPath(brush, bar);
                    using (var pen = new Pen(Color.FromArgb(90, 255, 255, 255), 4f))
                    {
                        for (var x = -36 + _shift; x < fill.Right; x += 16)
                            g.DrawLine(pen, x, fill.Bottom, x + fill.Height, fill.Top);
                    }
                    g.ResetClip();
                }
            }
            TextRenderer.DrawText(g, _caption, _font, rect, Color.White, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis);
        }
    }
}
