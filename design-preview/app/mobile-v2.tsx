"use client";

import { useEffect, useMemo, useState } from "react";
import {
  Activity,
  ArrowDown,
  ArrowLeft,
  ArrowRight,
  Bell,
  Check,
  CheckCircle2,
  ChevronRight,
  CircleAlert,
  ClipboardCheck,
  Clock3,
  Copy,
  Eye,
  EyeOff,
  FileText,
  Gauge,
  Home,
  Info,
  KeyRound,
  LayoutGrid,
  Link2,
  ListFilter,
  LoaderCircle,
  LockKeyhole,
  LogOut,
  Menu,
  Minus,
  MoreHorizontal,
  Radio,
  RefreshCw,
  Search,
  Settings,
  ShieldCheck,
  Sparkles,
  Swords,
  Target,
  TrendingUp,
  Trophy,
  UserRound,
  Users,
  WifiOff,
  X,
  XCircle,
  Zap,
} from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Switch } from "@/components/ui/switch";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { Toaster } from "@/components/ui/sonner";

type Screen = "auth" | "home" | "connect" | "analysis" | "league" | "recommendations" | "recommendation" | "reports" | "report" | "activity" | "settings";
type NetworkMode = "online" | "offline" | "error";
type Decision = "approved" | "dismissed";
type AuthMode = "signin" | "create" | "forgot";

type Recommendation = {
  id: string;
  type: "LINEUP" | "WAIVER" | "TRADE";
  title: string;
  summary: string;
  confidence: number;
  impact: string;
  risk: string;
  why: string;
  source: string;
  primary: { initials: string; name: string; meta: string; value: string };
  secondary: { initials: string; name: string; meta: string; value: string };
};

const recommendations: Recommendation[] = [
  {
    id: "rec-lineup",
    type: "LINEUP",
    title: "Start Jordan Addison over D. Hopkins",
    summary: "A stronger verified matchup and safer target floor this week.",
    confidence: 87,
    impact: "+4.8 pts",
    risk: "Monitor Friday injury report",
    why: "Addison has outpaced Hopkins in verified target share over the last three games and faces a defense allowing more production to outside receivers.",
    source: "ESPN Week 9 projections + verified 3-game usage",
    primary: { initials: "JA", name: "Jordan Addison", meta: "MIN • WR", value: "14.6" },
    secondary: { initials: "DH", name: "D. Hopkins", meta: "TEN • WR", value: "9.8" },
  },
  {
    id: "rec-waiver",
    type: "WAIVER",
    title: "Add Jaylen Wright for your RB depth",
    summary: "Available now and offers more rest-of-season upside than your current final bench spot.",
    confidence: 82,
    impact: "+2.6 ROS",
    risk: "Weekly role may fluctuate",
    why: "Wright is available in this demo league and has a clearer path to meaningful touches than the lowest-value verified roster option.",
    source: "League availability + roster need analysis",
    primary: { initials: "JW", name: "Jaylen Wright", meta: "MIA • RB", value: "Add" },
    secondary: { initials: "TB", name: "Final bench spot", meta: "LOWEST FIT", value: "Review" },
  },
  {
    id: "rec-trade",
    type: "TRADE",
    title: "Explore Aiyuk for James Cook",
    summary: "Balances positional depth for both teams without a clear verified value loss.",
    confidence: 74,
    impact: "Balanced",
    risk: "Manager acceptance is unknown",
    why: "Your roster has surplus wide-receiver depth while the other manager needs a starter there. Their running-back depth can support a fair conversation.",
    source: "Mutual roster fit + bounded value comparison",
    primary: { initials: "BA", name: "Brandon Aiyuk", meta: "SF • WR", value: "Offer" },
    secondary: { initials: "JC", name: "James Cook", meta: "BUF • RB", value: "Target" },
  },
];

const reports = [
  { id: "week-9", week: "09", title: "The waiver wire just changed the playoff picture.", meta: "Today • AI Narration", excerpt: "Three teams made meaningful gains, while the top seed faces its toughest matchup yet." },
  { id: "week-8", week: "08", title: "Two contenders separated themselves from the pack.", meta: "Oct 22 • Rules", excerpt: "Verified lineup efficiency created a clear gap between the top four teams." },
  { id: "week-7", week: "07", title: "Monday night decided the league’s closest matchup.", meta: "Oct 15 • Rules Fallback", excerpt: "A single flex decision changed the final result and the middle of the standings." },
];

const roster = [
  { pos: "QB", name: "Jalen Hurts", team: "PHI", projection: "22.8", tag: "Locked" },
  { pos: "RB", name: "Breece Hall", team: "NYJ", projection: "17.2", tag: "Start" },
  { pos: "RB", name: "Kyren Williams", team: "LAR", projection: "16.9", tag: "Start" },
  { pos: "WR", name: "A.J. Brown", team: "PHI", projection: "16.4", tag: "Start" },
  { pos: "WR", name: "Jordan Addison", team: "MIN", projection: "14.6", tag: "Suggested" },
  { pos: "FLEX", name: "D. Hopkins", team: "TEN", projection: "9.8", tag: "Review" },
];

const stages = ["Queued", "Synchronizing ESPN", "Optimizing lineup", "Scanning waivers", "Testing trade fit", "Building weekly report"];

function Brand({ small = false }: { small?: boolean }) {
  return <div className={`v2-brand ${small ? "small" : ""}`}><span><Zap /></span><strong>LEAGUEPILOT</strong><em>AI</em></div>;
}

function DemoLabel() { return <span className="v2-demo"><Sparkles /> Interactive prototype • Demo data</span>; }

function StatusBar() { return <div className="v2-status" aria-hidden="true"><strong>9:41</strong><span /><div>● ◒ ▰</div></div>; }

function Field({ label, placeholder, value, onChange, secure = false, hint }: { label: string; placeholder: string; value: string; onChange: (value: string) => void; secure?: boolean; hint?: string }) {
  const [visible, setVisible] = useState(false);
  return <label className="v2-field"><span>{label}</span><div><Input aria-label={label} placeholder={placeholder} value={value} onChange={(event) => onChange(event.target.value)} type={secure && !visible ? "password" : "text"} />{secure && <button type="button" aria-label={visible ? `Hide ${label}` : `Show ${label}`} onClick={() => setVisible(!visible)}>{visible ? <EyeOff /> : <Eye />}</button>}</div>{hint && <small>{hint}</small>}</label>;
}

function AppHeader({ title, eyebrow, back, action }: { title: string; eyebrow: string; back?: () => void; action?: React.ReactNode }) {
  return <header className="v2-header"><div className="v2-header-main">{back ? <button className="v2-circle" onClick={back} aria-label="Go back"><ArrowLeft /></button> : <Brand small />}<div><p>{eyebrow}</p><h1>{title}</h1></div></div>{action}</header>;
}

function BottomNav({ screen, navigate }: { screen: Screen; navigate: (screen: Screen) => void }) {
  const normalized = screen === "recommendation" ? "recommendations" : screen === "report" ? "reports" : screen;
  const items = [{ id: "home" as Screen, label: "Home", icon: Home }, { id: "recommendations" as Screen, label: "Decisions", icon: Sparkles }, { id: "reports" as Screen, label: "Reports", icon: FileText }, { id: "settings" as Screen, label: "Settings", icon: Settings }];
  return <nav className="v2-bottom" aria-label="Primary navigation">{items.map(({ id, label, icon: Icon }) => <button key={id} className={normalized === id ? "active" : ""} onClick={() => navigate(id)}><span><Icon /></span><small>{label}</small></button>)}</nav>;
}

function AuthScreen({ onAuthenticated }: { onAuthenticated: (demo?: boolean) => void }) {
  const [mode, setMode] = useState<AuthMode>("signin");
  const [fullName, setFullName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const submit = () => {
    if ((mode === "create" && !fullName.trim()) || !email.includes("@") || (mode !== "forgot" && password.length < 8)) { setError(mode === "forgot" ? "Enter a valid email address." : mode === "create" ? "Enter your name, a valid email and at least 8 password characters." : "Use a valid email and at least 8 password characters."); return; }
    setError(""); setLoading(true); window.setTimeout(() => { setLoading(false); if (mode === "forgot") { toast.success("Prototype recovery state complete"); setMode("signin"); } else onAuthenticated(false); }, 800);
  };
  return <div className="v2-screen v2-auth"><div className="v2-auth-grid" aria-hidden="true"><i /><i /><i /><i /></div><div className="v2-auth-top"><Brand /><DemoLabel /></div><div className="v2-auth-core"><div className="v2-auth-signal"><span><Radio /></span><p>NATIVE SWIFTUI • ESPN-FIRST INTELLIGENCE</p></div><h1>{mode === "create" ? "Build your weekly edge." : mode === "forgot" ? "Recover your command center." : "Every week starts here."}</h1><p>{mode === "forgot" ? "Enter your account email to preview the recovery flow." : "Turn your real league into a clear, evidence-backed game plan—without giving up control."}</p><div className="v2-auth-form">{mode === "create" && <Field label="Full name" placeholder="Your full name" value={fullName} onChange={setFullName} />}<Field label="Email address" placeholder="you@example.com" value={email} onChange={setEmail} />{mode !== "forgot" && <Field label="Password" placeholder="At least 8 characters" value={password} onChange={setPassword} secure />}{error && <div className="v2-inline-error"><CircleAlert />{error}</div>}<Button className="v2-primary" onClick={submit} disabled={loading}>{loading ? <><LoaderCircle className="spin" />Preparing command center…</> : mode === "create" ? "Create account" : mode === "forgot" ? "Preview recovery" : "Sign in"}<ArrowRight /></Button><button className="v2-demo-entry" onClick={() => onAuthenticated(true)}><Sparkles /> Explore the complete demo</button></div><div className="v2-auth-links">{mode === "signin" && <button onClick={() => setMode("forgot")}>Forgot password?</button>}<button onClick={() => setMode(mode === "create" ? "signin" : "create")}>{mode === "create" ? "Already have an account? Sign in" : "New manager? Create an account"}</button>{mode === "forgot" && <button onClick={() => setMode("signin")}><ArrowLeft />Back to sign in</button>}</div></div><div className="v2-auth-proof"><span><ShieldCheck />Keychain session model</span><span><ClipboardCheck />Human approval required</span></div></div>;
}

function DisconnectedHome({ navigate }: { navigate: (screen: Screen) => void }) {
  return <div className="v2-screen v2-with-nav"><AppHeader title="Your command center" eyebrow="WELCOME, COLTON" action={<button className="v2-avatar" onClick={() => navigate("settings")}>CW</button>} /><main className="v2-scroll v2-home"><DemoLabel /><section className="v2-connect-hero"><div className="v2-connect-radar"><span><Link2 /></span><i /><i /><i /></div><p className="v2-overline">ONE SECURE CONNECTION</p><h2>Bring your ESPN league into focus.</h2><p>We’ll organize your roster, matchup, waiver market and league context into one weekly decision system.</p><Button className="v2-primary" onClick={() => navigate("connect")}>Connect ESPN league<ArrowRight /></Button><div><ShieldCheck />Encrypted <i>•</i> Read-only <i>•</i> Never posts moves</div></section><section className="v2-flow-preview"><p className="v2-overline">YOUR WEEKLY FLOW</p>{[{ n: "01", title: "Sync the real league", note: "No mystery numbers or fabricated gaps." }, { n: "02", title: "Find the clearest edges", note: "Lineup, waivers, trades and reports." }, { n: "03", title: "Make the final call", note: "Every ESPN action stays with you." }].map((item) => <div key={item.n}><span>{item.n}</span><p><strong>{item.title}</strong><small>{item.note}</small></p></div>)}</section></main><BottomNav screen="home" navigate={navigate} /></div>;
}

function ConnectScreen({ onConnected, back }: { onConnected: () => void; back: () => void }) {
  const [leagueId, setLeagueId] = useState("");
  const [teamId, setTeamId] = useState("");
  const [season, setSeason] = useState("2026");
  const [privateLeague, setPrivateLeague] = useState(false);
  const [espnS2, setEspnS2] = useState("");
  const [swid, setSwid] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const connect = () => {
    if (!leagueId || !teamId || !season) { setError("League ID, team ID and season are required."); return; }
    if (privateLeague && (!espnS2 || !swid)) { setError("Private leagues require both secure ESPN credentials."); return; }
    setError(""); setLoading(true); window.setTimeout(() => { setEspnS2(""); setSwid(""); setLoading(false); toast.success("League connected securely"); onConnected(); }, 1050);
  };
  return <div className="v2-screen"><AppHeader title="Connect ESPN" eyebrow="SECURE SETUP • STEP 1 OF 1" back={back} /><main className="v2-scroll v2-connect"><DemoLabel /><section className="v2-security-banner"><span><ShieldCheck /></span><p><strong>Read-only by design</strong><small>Credentials are encrypted, never displayed again and never used to submit moves.</small></p></section><div className="v2-form-stack"><Field label="League ID" placeholder="Example: 123456789" value={leagueId} onChange={setLeagueId} hint="Find it after leagueId= in your ESPN league URL." /><div className="v2-form-pair"><Field label="Team ID" placeholder="Example: 4" value={teamId} onChange={setTeamId} /><Field label="Season" placeholder="2026" value={season} onChange={setSeason} /></div><label className="v2-toggle"><span><strong>Private league</strong><small>Requires current ESPN browser credentials</small></span><Switch checked={privateLeague} onCheckedChange={setPrivateLeague} /></label>{privateLeague && <div className="v2-secret-box"><p><LockKeyhole />Secure values disappear immediately after submission.</p><Field label="espn_s2" placeholder="Paste secure cookie" value={espnS2} onChange={setEspnS2} secure /><Field label="SWID" placeholder="{XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX}" value={swid} onChange={setSwid} secure /></div>}{error && <div className="v2-inline-error"><CircleAlert />{error}</div>}<button className="v2-help"><Info />Where do I find my ESPN IDs?</button></div></main><footer className="v2-sticky"><Button className="v2-primary" onClick={connect} disabled={loading}>{loading ? <><LoaderCircle className="spin" />Connecting securely…</> : <>Connect league<ArrowRight /></>}</Button><p><ShieldCheck />Encrypted • Read-only • Human controlled</p></footer></div>;
}

function MatchupDeck({ navigate }: { navigate: (screen: Screen) => void }) {
  return <button className="v2-deck" onClick={() => navigate("league")}><div className="v2-deck-lines" aria-hidden="true"><i /><i /><i /><i /></div><div className="v2-deck-top"><span><CheckCircle2 />ESPN LIVE</span><small>Synced 8 min ago</small></div><div className="v2-deck-title"><div><p>CAROLINA CHAOS</p><h2>Fourth & Reckless</h2></div><ChevronRight /></div><div className="v2-matchup"><div><small>YOU</small><strong>126.4</strong><span>6–2 record</span></div><div className="v2-matchup-center"><Swords /><span>WEEK 9</span></div><div><small>GRIDIRON KINGS</small><strong>124.8</strong><span>5–3 record</span></div></div><div className="v2-edge-bar"><span style={{ width: "62%" }} /><p><strong>+1.6</strong> projected edge</p></div></button>;
}

function RecommendationCard({ rec, decision, open }: { rec: Recommendation; decision?: Decision; open: () => void }) {
  const icon = rec.type === "LINEUP" ? <Target /> : rec.type === "WAIVER" ? <Users /> : <Activity />;
  return <button className={`v2-rec v2-${rec.type.toLowerCase()}`} onClick={open}><div className="v2-rec-head"><span>{icon}{rec.type}</span>{decision ? <em className={decision}>{decision}</em> : <em>{rec.confidence}% confidence</em>}</div><h3>{rec.title}</h3><p>{rec.summary}</p><div className="v2-rec-foot"><strong><TrendingUp />{rec.impact}</strong><span><CircleAlert />{rec.risk}</span></div></button>;
}

function ConnectedHome({ navigate, runAnalysis, decisions, lastSync }: { navigate: (screen: Screen, id?: string) => void; runAnalysis: () => void; decisions: Record<string, Decision>; lastSync: string }) {
  const openDecisions = recommendations.filter((rec) => !decisions[rec.id]);
  return <div className="v2-screen v2-with-nav"><AppHeader title="Your weekly edge" eyebrow="WEEK 9 • COMMAND READY" action={<div className="v2-head-actions"><button onClick={() => navigate("activity")} aria-label="Open activity"><Bell /><i /></button><button className="v2-avatar" onClick={() => navigate("settings")} aria-label="Open settings">CW</button></div>} /><main className="v2-scroll v2-home"><DemoLabel /><MatchupDeck navigate={navigate} /><section className="v2-readiness"><div className="v2-readiness-ring" style={{ "--score": "92%" } as React.CSSProperties}><span><strong>92</strong><small>READY</small></span></div><div><p className="v2-overline">WEEKLY READINESS</p><h2>Your roster is ready. Two decisions could create separation.</h2><span>Lineup verified • Waiver market scanned • Report ready</span></div></section><button className="v2-analysis-button" onClick={runAnalysis}><span><Zap /></span><p><strong>Refresh my competitive edge</strong><small>Sync league → evaluate every decision → build report</small></p><ArrowRight /></button><div className="v2-section-title"><div><p>PRIORITY BRIEF</p><h2>{openDecisions.length || 0} decisions worth your attention</h2></div><button onClick={() => navigate("recommendations")}>View queue</button></div><div className="v2-home-recs">{openDecisions.slice(0, 2).map((rec) => <RecommendationCard key={rec.id} rec={rec} open={() => navigate("recommendation", rec.id)} />)}{openDecisions.length === 0 && <div className="v2-empty"><CheckCircle2 /><p><strong>You’re cleared for kickoff</strong><span>Every current recommendation has been reviewed.</span></p></div>}</div><div className="v2-intel-grid"><button onClick={() => navigate("league")}><span><LayoutGrid /></span><p><small>LEAGUE COMMAND</small><strong>Roster & matchup</strong></p><ChevronRight /></button><button onClick={() => navigate("report")}><span><FileText /></span><p><small>WEEKLY INTEL</small><strong>Open the full report</strong></p><ChevronRight /></button></div><div className="v2-data-note"><Info /><p><strong>Partial ESPN projection data</strong><span>Unavailable values stay unavailable. Current recommendations use only verified inputs.</span></p></div><p className="v2-last-sync">Last prototype sync: {lastSync}</p></main><BottomNav screen="home" navigate={navigate} /></div>;
}

function AnalysisScreen({ step, cancel, finish }: { step: number; cancel: () => void; finish: () => void }) {
  const complete = step >= stages.length;
  return <div className="v2-screen v2-analysis"><AppHeader title="Command scan" eyebrow="LIVE WEEKLY ANALYSIS" back={cancel} /><main className="v2-analysis-main"><DemoLabel /><div className={`v2-scan ${complete ? "complete" : ""}`}><span className="v2-scan-sweep" /><i /><i /><i /><div>{complete ? <Check /> : <Zap />}</div></div><div className="v2-scan-copy"><p>{complete ? "SCAN COMPLETE" : `STAGE ${step + 1} OF ${stages.length}`}</p><h2>{complete ? "Your Week 9 edge is ready." : stages[step]}</h2><span>{complete ? "Three evidence-backed decisions and a fresh report are ready for review." : "No fake percentages—progress follows completed analysis stages."}</span></div><ol className="v2-stage-list">{stages.map((stage, index) => <li key={stage} className={index < step || complete ? "done" : index === step ? "active" : ""}><span>{index < step || complete ? <Check /> : index === step ? <LoaderCircle className="spin" /> : index + 1}</span><p><strong>{stage}</strong><small>{index < step || complete ? "Complete" : index === step ? "Working" : "Waiting"}</small></p></li>)}</ol>{complete ? <Button className="v2-primary" onClick={finish}>Review decisions<ArrowRight /></Button> : <button className="v2-text-button" onClick={cancel}>Keep running in background</button>}</main></div>;
}

function LeagueScreen({ back, sync }: { back: () => void; sync: () => void }) {
  const [tab, setTab] = useState("lineup");
  return <div className="v2-screen"><AppHeader title="My league" eyebrow="CAROLINA CHAOS • WEEK 9" back={back} action={<button className="v2-circle" onClick={sync}><RefreshCw /></button>} /><main className="v2-scroll v2-league"><DemoLabel /><section className="v2-league-score"><div><p>YOUR TEAM</p><h2>Fourth & Reckless</h2><span>6–2 • 2nd place</span></div><div><small>POINTS FOR</small><strong>1,086.4</strong><em>2nd in league</em></div></section><section className="v2-match-card"><div><span>YOU</span><strong>126.4</strong><small>54% matchup edge</small></div><div className="v2-vs"><Swords /><span>THU–MON</span></div><div><span>OPPONENT</span><strong>124.8</strong><small>Gridiron Kings</small></div></section><Tabs value={tab} onValueChange={setTab}><TabsList className="v2-tabs"><TabsTrigger value="lineup">Lineup</TabsTrigger><TabsTrigger value="matchup">Matchup</TabsTrigger><TabsTrigger value="health">Connection</TabsTrigger></TabsList></Tabs>{tab === "lineup" && <section className="v2-roster"><div className="v2-roster-head"><span>STARTING LINEUP</span><small>Verified projections</small></div>{roster.map((player) => <div key={player.pos}><span className="v2-pos">{player.pos}</span><p><strong>{player.name}</strong><small>{player.team} • Week 9</small></p><em className={player.tag === "Suggested" ? "suggested" : ""}>{player.tag}</em><strong>{player.projection}</strong></div>)}</section>}{tab === "matchup" && <section className="v2-matchup-detail"><div className="v2-chart"><span style={{ height: "78%" }}><i>YOU</i></span><span style={{ height: "69%" }}><i>OPP</i></span></div><h3>Flex decisions decide this matchup.</h3><p>Your verified projection edge is narrow. The current lineup recommendation accounts for most of the available upside.</p></section>}{tab === "health" && <section className="v2-health"><div><CheckCircle2 /><p><strong>ESPN connection healthy</strong><span>Last successful sync: 8 minutes ago</span></p></div><div><ShieldCheck /><p><strong>Read-only access</strong><span>No write capability exists in this prototype.</span></p></div><Button variant="outline" onClick={sync}><RefreshCw />Sync now</Button></section>}</main></div>;
}

function RecommendationsScreen({ navigate, decisions }: { navigate: (screen: Screen, id?: string) => void; decisions: Record<string, Decision> }) {
  const [filter, setFilter] = useState("all");
  const visible = recommendations.filter((rec) => filter === "all" || filter === rec.type.toLowerCase() || decisions[rec.id] === filter);
  return <div className="v2-screen v2-with-nav"><AppHeader title="Decision center" eyebrow="WEEK 9 • EVIDENCE FIRST" action={<button className="v2-circle"><ListFilter /></button>} /><main className="v2-scroll v2-decisions"><DemoLabel /><section className="v2-decision-summary"><div><strong>{recommendations.filter((rec) => !decisions[rec.id]).length}</strong><span>OPEN</span></div><p><strong>Your queue, ranked by impact.</strong><small>Approval records intent—it never executes an ESPN move.</small></p></section><div className="v2-filter-scroll">{["all", "lineup", "waiver", "trade", "approved", "dismissed"].map((item) => <button key={item} className={filter === item ? "active" : ""} onClick={() => setFilter(item)}>{item}</button>)}</div><div className="v2-rec-list">{visible.map((rec) => <RecommendationCard key={rec.id} rec={rec} decision={decisions[rec.id]} open={() => navigate("recommendation", rec.id)} />)}{visible.length === 0 && <div className="v2-empty"><Search /><p><strong>No decisions in this view</strong><span>Choose another filter to keep exploring.</span></p></div>}</div><div className="v2-trust-note"><ShieldCheck /><p><strong>You stay in control</strong><span>Every recommendation includes its evidence, confidence, risk and freshness.</span></p></div></main><BottomNav screen="recommendations" navigate={navigate} /></div>;
}

function RecommendationScreen({ rec, decision, back, decide }: { rec: Recommendation; decision?: Decision; back: () => void; decide: (decision: Decision) => void }) {
  const [confirm, setConfirm] = useState<Decision | null>(null);
  return <div className="v2-screen"><AppHeader title="Decision brief" eyebrow={`${rec.type} • GENERATED 12 MIN AGO`} back={back} action={<button className="v2-circle"><MoreHorizontal /></button>} /><main className="v2-scroll v2-rec-detail"><DemoLabel /><section className={`v2-rec-hero v2-${rec.type.toLowerCase()}`}><div><span>{rec.type}</span><em>Fresh</em></div><h2>{rec.title}</h2><div><p><small>CONFIDENCE</small><strong>{rec.confidence}%</strong><i><b style={{ width: `${rec.confidence}%` }} /></i></p><p><small>EST. IMPACT</small><strong>{rec.impact}</strong></p></div></section><section className="v2-why"><p className="v2-overline">WHY THIS MAKES SENSE</p><h3>{rec.summary}</h3><p>{rec.why}</p></section><section className="v2-compare"><header><span>PLAYER COMPARISON</span><small>Verified inputs</small></header><div className="primary"><span>{rec.primary.initials}</span><p><small>PRIMARY</small><strong>{rec.primary.name}</strong><em>{rec.primary.meta}</em></p><strong>{rec.primary.value}</strong></div><div className="v2-versus"><i />VS<i /></div><div><span>{rec.secondary.initials}</span><p><small>COMPARE</small><strong>{rec.secondary.name}</strong><em>{rec.secondary.meta}</em></p><strong>{rec.secondary.value}</strong></div></section><section className="v2-evidence"><div><Target /><p><strong>Evidence source</strong><span>{rec.source}</span></p></div><div className="risk"><CircleAlert /><p><strong>Risk to monitor</strong><span>{rec.risk}</span></p></div><div><Clock3 /><p><strong>Freshness</strong><span>Generated 12 minutes ago • Valid for Week 9</span></p></div></section><div className="v2-approval-note"><Info /><p><strong>Approval records your decision only.</strong><span>LEAGUEPILOT AI does not execute this move on ESPN.</span></p></div>{decision && <div className={`v2-recorded ${decision}`}><CheckCircle2 /><p><strong>Decision recorded: {decision}</strong><span>{decision === "approved" ? "No ESPN action was taken." : "This remains available in your dismissed history."}</span></p></div>}</main>{!decision && <footer className="v2-decision-footer"><Button variant="outline" onClick={() => setConfirm("dismissed")}><X />Dismiss</Button><Button className="v2-primary" onClick={() => setConfirm("approved")}><Check />Approve</Button></footer>}<AlertDialog open={!!confirm} onOpenChange={(open) => !open && setConfirm(null)}><AlertDialogContent className="v2-dialog"><AlertDialogHeader><AlertDialogTitle>{confirm === "approved" ? "Record this approval?" : "Dismiss this decision?"}</AlertDialogTitle><AlertDialogDescription>{confirm === "approved" ? "This saves your intent only. You still make the actual change yourself in ESPN." : "You can review it later under Dismissed."}</AlertDialogDescription></AlertDialogHeader><AlertDialogFooter><AlertDialogCancel>Go back</AlertDialogCancel><AlertDialogAction onClick={() => { if (confirm) decide(confirm); setConfirm(null); }}>Record decision</AlertDialogAction></AlertDialogFooter></AlertDialogContent></AlertDialog></div>;
}

function ReportsScreen({ navigate }: { navigate: (screen: Screen, id?: string) => void }) {
  return <div className="v2-screen v2-with-nav"><AppHeader title="League reports" eyebrow="CAROLINA CHAOS • 2026" action={<button className="v2-circle"><Search /></button>} /><main className="v2-scroll v2-reports"><DemoLabel /><button className="v2-feature-report" onClick={() => navigate("report", reports[0].id)}><div className="v2-feature-art"><span><Trophy /></span><i /><i /><i /></div><p>WEEK 9 • LATEST</p><h2>{reports[0].title}</h2><span>{reports[0].excerpt}</span><strong>Read report <ArrowRight /></strong></button><div className="v2-section-title"><div><p>ARCHIVE</p><h2>Every week, explained.</h2></div></div><div className="v2-report-list">{reports.map((report) => <button key={report.id} onClick={() => navigate("report", report.id)}><span><small>WEEK</small><strong>{report.week}</strong></span><p><strong>{report.title}</strong><small>{report.meta}</small></p><ChevronRight /></button>)}</div></main><BottomNav screen="reports" navigate={navigate} /></div>;
}

function ReportScreen({ report, back }: { report: typeof reports[number]; back: () => void }) {
  const copy = async () => { await navigator.clipboard?.writeText(report.title); toast.success("Report copied"); };
  return <div className="v2-screen"><AppHeader title={`Week ${Number(report.week)} report`} eyebrow="CAROLINA CHAOS • PUBLISHED" back={back} action={<button className="v2-circle" onClick={copy}><Copy /></button>} /><main className="v2-scroll v2-report-detail"><DemoLabel /><header><span>WEEKLY INTELLIGENCE</span><h1>{report.title}</h1><p>{report.excerpt}</p><div><em>{report.meta.split(" • ")[1]}</em><em>5 min read</em></div></header><section><b>01</b><div><p className="v2-overline">POWER RANKINGS</p><h2>A new team takes the top spot</h2><p>Fourth & Reckless moves to No. 1 after pairing the strongest verified scoring trend with a favorable Week 9 matchup.</p><div className="v2-ranking"><strong>1</strong><span>FR</span><p><b>Fourth & Reckless</b><small>Up 2 positions</small></p><TrendingUp /></div></div></section><section><b>02</b><div><p className="v2-overline">MATCHUP TO WATCH</p><h2>The week’s closest projection</h2><p>Less than two verified points separate Carolina Chaos and Gridiron Kings. Flex decisions could decide it.</p><div className="v2-report-match"><p><small>CHAOS</small><strong>126.4</strong></p><Swords /><p><small>KINGS</small><strong>124.8</strong></p></div></div></section><section><b>03</b><div><p className="v2-overline">MANAGER EFFICIENCY</p><h2>Bench decisions mattered</h2><p>Two managers left verified double-digit scorers outside their starting lineup. Missing projections were not counted.</p></div></section><div className="v2-narration"><Sparkles /><p><strong>Narration disclosure</strong><span>This report uses AI narration over verified analysis. Model prose cannot authorize account actions.</span></p></div></main><footer className="v2-share"><Button variant="outline" onClick={copy}><Copy />Copy</Button><Button className="v2-primary" onClick={() => toast.success("Native share preview opened")}>Share report<ArrowRight /></Button></footer></div>;
}

function ActivityScreen({ back }: { back: () => void }) {
  const events = [{ icon: CheckCircle2, title: "Analysis completed", note: "3 decisions • Week 9 report", time: "2 min ago", tone: "success" }, { icon: RefreshCw, title: "ESPN sync completed", note: "League snapshot updated", time: "8 min ago", tone: "normal" }, { icon: ClipboardCheck, title: "Decision approved", note: "Start Jordan Addison", time: "Yesterday", tone: "lime" }, { icon: Link2, title: "ESPN connected", note: "Carolina Chaos • 2026", time: "Oct 12", tone: "normal" }];
  return <div className="v2-screen"><AppHeader title="Activity" eyebrow="SAFE WORKSPACE HISTORY" back={back} /><main className="v2-scroll v2-activity"><DemoLabel /><section className="v2-job"><header><span><Zap /></span><p><small>LATEST JOB</small><strong>Full weekly analysis</strong></p><em>Completed</em></header><div><p><small>ATTEMPTS</small><strong>1</strong></p><p><small>STARTED</small><strong>2:14 PM</strong></p><p><small>DURATION</small><strong>42 sec</strong></p></div></section><div className="v2-section-title"><div><p>AUDIT TRAIL</p><h2>Recent activity</h2></div></div><div className="v2-timeline">{events.map(({ icon: Icon, ...event }, index) => <div key={event.title} className={event.tone}><span><Icon /></span><p><strong>{event.title}</strong><small>{event.note}</small><em>{event.time}</em></p>{index < events.length - 1 && <i />}</div>)}</div></main></div>;
}

function SettingsScreen({ navigate, sync, disconnect, signOut, connected }: { navigate: (screen: Screen) => void; sync: () => void; disconnect: () => void; signOut: () => void; connected: boolean }) {
  const [confirm, setConfirm] = useState<"disconnect" | "signout" | null>(null);
  const row = (Icon: typeof Home, title: string, note: string, action?: () => void, disabled = false) => <button onClick={action} disabled={disabled}><span><Icon /></span><p><strong>{title}</strong><small>{note}</small></p>{!disabled && <ChevronRight />}</button>;
  return <div className="v2-screen v2-with-nav"><AppHeader title="Settings" eyebrow="ACCOUNT & WORKSPACE" /><main className="v2-scroll v2-settings"><DemoLabel /><section className="v2-profile"><span>CW</span><p><strong>Colton Wood</strong><small>colton@example.com</small></p><ChevronRight /></section><div className="v2-setting-group"><h2>WORKSPACE</h2><section>{row(Gauge, "My Command Center", "Founder Beta workspace")}{row(Copy, "Workspace ID", "ws_••••29ad", () => toast.success("Workspace ID copied"))}{row(Activity, "Activity & jobs", "Safe workspace history", () => navigate("activity"))}</section></div><div className="v2-setting-group"><h2>ESPN</h2><section>{row(Link2, connected ? "Carolina Chaos" : "Not connected", connected ? "Healthy • Synced 8 min ago" : "Connect your league", () => navigate(connected ? "league" : "connect"))}{row(RefreshCw, "Sync now", connected ? "Refresh league snapshot" : "Connect ESPN first", connected ? sync : undefined, !connected)}{connected && row(XCircle, "Disconnect ESPN", "Removes this prototype connection", () => setConfirm("disconnect"))}</section></div><div className="v2-setting-group"><h2>PREFERENCES</h2><section>{row(Bell, "Notifications", "Coming after mobile implementation", undefined, true)}{row(Sparkles, "Report preferences", "Coming after mobile implementation", undefined, true)}</section></div><section className="v2-privacy"><ShieldCheck /><p><strong>Your data. Your decisions.</strong><span>Read-only access, encrypted credentials and human approval are built into every workflow.</span></p></section><button className="v2-signout" onClick={() => setConfirm("signout")}><LogOut />Sign out</button></main><BottomNav screen="settings" navigate={navigate} /><AlertDialog open={!!confirm} onOpenChange={(open) => !open && setConfirm(null)}><AlertDialogContent className="v2-dialog"><AlertDialogHeader><AlertDialogTitle>{confirm === "disconnect" ? "Disconnect ESPN?" : "Sign out of the prototype?"}</AlertDialogTitle><AlertDialogDescription>{confirm === "disconnect" ? "This clears the saved prototype league connection. No live ESPN account is affected." : "Your local prototype journey will return to Sign In."}</AlertDialogDescription></AlertDialogHeader><AlertDialogFooter><AlertDialogCancel>Cancel</AlertDialogCancel><AlertDialogAction onClick={() => { if (confirm === "disconnect") disconnect(); else signOut(); setConfirm(null); }}>Continue</AlertDialogAction></AlertDialogFooter></AlertDialogContent></AlertDialog></div>;
}

function NetworkOverlay({ mode, close }: { mode: NetworkMode; close: () => void }) {
  if (mode === "online") return null;
  return <div className="v2-network"><div>{mode === "offline" ? <WifiOff /> : <XCircle />}<p className="v2-overline">SAFE RECOVERY STATE</p><h2>{mode === "offline" ? "You’re offline." : "ESPN is temporarily unavailable."}</h2><p>{mode === "offline" ? "Your last prototype view remains available. Reconnect to sync fresh league data." : "Your connection is safe. No credentials need to be entered again."}</p><Button className="v2-primary" onClick={close}>{mode === "offline" ? "View saved data" : "Try again"}</Button></div></div>;
}

export function LeaguePilotV2() {
  const [screen, setScreen] = useState<Screen>("auth");
  const [authenticated, setAuthenticated] = useState(false);
  const [connected, setConnected] = useState(false);
  const [analysisStep, setAnalysisStep] = useState(0);
  const [analysisRunning, setAnalysisRunning] = useState(false);
  const [selectedRec, setSelectedRec] = useState(recommendations[0].id);
  const [selectedReport, setSelectedReport] = useState(reports[0].id);
  const [decisions, setDecisions] = useState<Record<string, Decision>>({});
  const [network, setNetwork] = useState<NetworkMode>("online");
  const [menuOpen, setMenuOpen] = useState(false);
  const [lastSync, setLastSync] = useState("8 minutes ago");
  const [hydrated, setHydrated] = useState(false);

  useEffect(() => {
    try {
      const saved = window.localStorage.getItem("leaguepilot-preview-v2");
      if (saved) {
        const state = JSON.parse(saved);
        setAuthenticated(!!state.authenticated); setConnected(!!state.connected); setDecisions(state.decisions || {}); setLastSync(state.lastSync || "8 minutes ago"); setScreen(state.authenticated ? "home" : "auth");
      }
    } catch { /* prototype storage is optional */ }
    setHydrated(true);
  }, []);

  useEffect(() => {
    if (!hydrated) return;
    window.localStorage.setItem("leaguepilot-preview-v2", JSON.stringify({ authenticated, connected, decisions, lastSync }));
  }, [authenticated, connected, decisions, lastSync, hydrated]);

  useEffect(() => {
    if (!analysisRunning) return;
    if (analysisStep >= stages.length) { setAnalysisRunning(false); return; }
    const timer = window.setTimeout(() => setAnalysisStep((step) => step + 1), 720);
    return () => window.clearTimeout(timer);
  }, [analysisRunning, analysisStep]);

  const navigate = (next: Screen, id?: string) => { if (id && next === "recommendation") setSelectedRec(id); if (id && next === "report") setSelectedReport(id); setScreen(next); setMenuOpen(false); setNetwork("online"); };
  const authenticate = (demo = false) => { setAuthenticated(true); setConnected(demo); setScreen("home"); toast.success(demo ? "Complete demo command center loaded" : "Workspace prepared"); };
  const runAnalysis = () => { setAnalysisStep(0); setAnalysisRunning(true); setScreen("analysis"); };
  const sync = () => { setLastSync("just now"); toast.success("Prototype sync completed"); };
  const decide = (decision: Decision) => { setDecisions((current) => ({ ...current, [selectedRec]: decision })); toast.success("Decision recorded — no ESPN action taken"); };
  const signOut = () => { setAuthenticated(false); setConnected(false); setDecisions({}); setScreen("auth"); window.localStorage.removeItem("leaguepilot-preview-v2"); };
  const activeRec = recommendations.find((rec) => rec.id === selectedRec) || recommendations[0];
  const activeReport = reports.find((report) => report.id === selectedReport) || reports[0];

  const rendered = useMemo(() => {
    if (!authenticated || screen === "auth") return <AuthScreen onAuthenticated={authenticate} />;
    if (screen === "home") return connected ? <ConnectedHome navigate={navigate} runAnalysis={runAnalysis} decisions={decisions} lastSync={lastSync} /> : <DisconnectedHome navigate={navigate} />;
    if (screen === "connect") return <ConnectScreen onConnected={() => { setConnected(true); setScreen("home"); }} back={() => setScreen("home")} />;
    if (screen === "analysis") return <AnalysisScreen step={analysisStep} cancel={() => setScreen("home")} finish={() => setScreen("recommendations")} />;
    if (screen === "league") return <LeagueScreen back={() => setScreen("home")} sync={sync} />;
    if (screen === "recommendations") return <RecommendationsScreen navigate={navigate} decisions={decisions} />;
    if (screen === "recommendation") return <RecommendationScreen rec={activeRec} decision={decisions[activeRec.id]} back={() => setScreen("recommendations")} decide={decide} />;
    if (screen === "reports") return <ReportsScreen navigate={navigate} />;
    if (screen === "report") return <ReportScreen report={activeReport} back={() => setScreen("reports")} />;
    if (screen === "activity") return <ActivityScreen back={() => setScreen("settings")} />;
    return <SettingsScreen navigate={navigate} sync={sync} disconnect={() => { setConnected(false); setScreen("home"); toast.success("Prototype ESPN connection removed"); }} signOut={signOut} connected={connected} />;
  }, [authenticated, screen, connected, decisions, lastSync, analysisStep, activeRec, activeReport]);

  const jumpItems = [{ id: "home" as Screen, label: "Game plan", icon: Home }, { id: "league" as Screen, label: "My League", icon: Trophy }, { id: "analysis" as Screen, label: "Command scan", icon: Zap }, { id: "recommendations" as Screen, label: "Decision center", icon: Target }, { id: "reports" as Screen, label: "League reports", icon: FileText }, { id: "activity" as Screen, label: "Activity", icon: Activity }, { id: "settings" as Screen, label: "Settings", icon: Settings }];

  return <main className="v2-shell"><aside className={`v2-control ${menuOpen ? "open" : ""}`}><header><Brand /><button onClick={() => setMenuOpen(false)} aria-label="Close preview menu"><X /></button></header><div className="v2-control-intro"><p>V3 • PREMIUM NATIVE DIRECTION</p><h1>Your league’s weekly command brief.</h1><span>A sharper, more readable system built around one job: identify the decisions that can actually change your week.</span></div><button className="v2-journey" onClick={() => { signOut(); setMenuOpen(false); }}><KeyRound /><span><strong>Experience the full journey</strong><small>Sign in → connect → analyze → decide</small></span><ArrowRight /></button><nav><h2>QUICK JUMP</h2>{jumpItems.map(({ id, label, icon: Icon }) => <button key={id} className={screen === id ? "active" : ""} onClick={() => { if (!authenticated) setAuthenticated(true); if (id !== "home" && !connected) setConnected(true); if (id === "analysis") { setAnalysisStep(0); setAnalysisRunning(true); } navigate(id); }}><Icon /><span>{label}</span>{screen === id && <Check />}</button>)}</nav><section className="v2-test-states"><h2>TEST RECOVERY</h2><div><button className={network === "offline" ? "active" : ""} onClick={() => setNetwork(network === "offline" ? "online" : "offline")}><WifiOff />Offline</button><button className={network === "error" ? "active" : ""} onClick={() => setNetwork(network === "error" ? "online" : "error")}><CircleAlert />ESPN error</button></div></section><footer><span><ShieldCheck />Data-honest prototype</span><span>SwiftUI base • 393 × 852</span></footer></aside><section className="v2-stage"><button className="v2-mobile-menu" onClick={() => setMenuOpen(true)}><Menu />Preview menu</button><div className="v2-stage-meta"><span><i />LIVE V3 PROTOTYPE</span><span>Premium native direction • 393 × 852</span></div><div className="v2-phone"><StatusBar /><div className="v2-viewport">{hydrated ? rendered : <div className="v2-loading"><LoaderCircle className="spin" />Loading command center…</div>}<NetworkOverlay mode={network} close={() => setNetwork("online")} /></div><div className="v2-home-bar" /></div><p className="v2-stage-note"><Info />Functional design reference. Native handoff excludes every piece of preview-only device chrome.</p></section><Toaster richColors position="top-center" /></main>;
}
