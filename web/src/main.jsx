import React, { useEffect, useMemo, useState } from 'react'
import { createRoot } from 'react-dom/client'
import { createClient } from '@supabase/supabase-js'
import './styles.css'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseKey = import.meta.env.VITE_SUPABASE_ANON_KEY
const siteUrl = (import.meta.env.VITE_SITE_URL || window.location.origin).replace(/\/$/, '')
const supabase = supabaseUrl && supabaseKey
  ? createClient(supabaseUrl, supabaseKey, { auth: { autoRefreshToken: true, persistSession: true, detectSessionInUrl: true } })
  : null

function App() {
  const [session, setSession] = useState(null)
  const [authMode, setAuthMode] = useState('login')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [displayName, setDisplayName] = useState('')
  const [busy, setBusy] = useState(false)
  const [notice, setNotice] = useState('')
  const [error, setError] = useState('')
  const [posts, setPosts] = useState([])
  const [caption, setCaption] = useState('')
  const [tab, setTab] = useState('Home')
  const [profile, setProfile] = useState(null)

  const configured = Boolean(supabase)
  const callback = window.location.pathname === '/auth/callback'

  useEffect(() => {
    if (!supabase) return
    const hash = new URLSearchParams(window.location.hash.replace(/^#/, ''))
    const code = new URLSearchParams(window.location.search).get('code')
    const authError = hash.get('error_description') || hash.get('error')
    if (authError) setError(decodeURIComponent(authError.replace(/\+/g, ' ')))
    if (callback && code) {
      supabase.auth.exchangeCodeForSession(code).then(({ error }) => {
        if (error) setError(error.message)
        else {
          setNotice('Email confirmed. Welcome to AIRGRAM!')
          window.history.replaceState({}, document.title, '/')
        }
      })
    }
    supabase.auth.getSession().then(({ data }) => setSession(data.session))
    const { data: listener } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      setSession(nextSession)
      if (nextSession) {
        setError('')
        setNotice('You are signed in.')
        window.history.replaceState({}, document.title, '/')
      }
    })
    return () => listener.subscription.unsubscribe()
  }, [callback])

  useEffect(() => {
    if (!session || !supabase) return
    loadProfile(session.user)
    loadFeed()
  }, [session])

  async function loadProfile(user) {
    const base = (user.email?.split('@')[0] || 'creator').toLowerCase().replace(/[^a-z0-9_.]/g, '').slice(0, 22) || 'creator'
    const candidate = base.length < 3 ? `user_${base}` : base
    const { data: existing } = await supabase.from('airgram_profiles').select('*').eq('id', user.id).maybeSingle()
    if (existing) { setProfile(existing); return }
    const { data, error: profileError } = await supabase.from('airgram_profiles').insert({
      id: user.id,
      username: `${candidate}_${user.id.slice(0, 5)}`,
      display_name: user.user_metadata?.display_name || displayName || candidate
    }).select().single()
    if (!profileError) setProfile(data)
  }

  async function loadFeed() {
    if (!supabase) return
    const { data, error: feedError } = await supabase.from('airgram_posts')
      .select('id,author_id,caption,created_at')
      .eq('status', 'published').eq('visibility', 'public')
      .order('created_at', { ascending: false }).limit(40)
    if (feedError) { setError(feedError.message); return }
    const ids = [...new Set((data || []).map(p => p.author_id))]
    let people = []
    let likes = []
    if (ids.length) {
      const [profilesResult, likesResult] = await Promise.all([
        supabase.from('airgram_profiles').select('id,username,display_name,avatar_url').in('id', ids),
        supabase.from('airgram_likes').select('post_id,user_id').in('post_id', (data || []).map(p => p.id))
      ])
      people = profilesResult.data || []
      likes = likesResult.data || []
    }
    setPosts((data || []).map(post => ({
      ...post,
      author: people.find(p => p.id === post.author_id),
      likes: likes.filter(l => l.post_id === post.id).length,
      liked: likes.some(l => l.post_id === post.id && l.user_id === session?.user?.id)
    })))
  }

  async function submitAuth(event) {
    event.preventDefault()
    if (!supabase) return
    setBusy(true); setError(''); setNotice('')
    try {
      if (authMode === 'signup') {
        const { data, error: signUpError } = await supabase.auth.signUp({
          email: email.trim(), password,
          options: {
            emailRedirectTo: `${siteUrl}/auth/callback`,
            data: { display_name: displayName.trim() }
          }
        })
        if (signUpError) throw signUpError
        if (!data.session) setNotice('Confirmation email sent. Open the newest AIRGRAM email to verify your address, then return here.')
      } else if (authMode === 'reset') {
        const { error: resetError } = await supabase.auth.resetPasswordForEmail(email.trim(), { redirectTo: `${siteUrl}/auth/callback` })
        if (resetError) throw resetError
        setNotice('Password reset email sent. Check your inbox.')
      } else {
        const { error: loginError } = await supabase.auth.signInWithPassword({ email: email.trim(), password })
        if (loginError) throw loginError
      }
    } catch (err) { setError(err.message || 'Authentication failed.') }
    finally { setBusy(false) }
  }

  async function publish(event) {
    event.preventDefault()
    if (!caption.trim() || !session) return
    setBusy(true); setError(''); setNotice('')
    const { error: publishError } = await supabase.from('airgram_posts').insert({
      author_id: session.user.id, caption: caption.trim(), visibility: 'public', status: 'published'
    })
    if (publishError) setError(publishError.message)
    else { setCaption(''); setNotice('Your post is live.'); setTab('Home'); await loadFeed() }
    setBusy(false)
  }

  async function toggleLike(post) {
    if (!session) return
    const next = !post.liked
    setPosts(current => current.map(p => p.id === post.id ? { ...p, liked: next, likes: p.likes + (next ? 1 : -1) } : p))
    const result = next
      ? await supabase.from('airgram_likes').insert({ post_id: post.id, user_id: session.user.id })
      : await supabase.from('airgram_likes').delete().eq('post_id', post.id).eq('user_id', session.user.id)
    if (result.error) { setError(result.error.message); await loadFeed() }
  }

  async function signOut() {
    await supabase.auth.signOut()
    setProfile(null); setPosts([]); setTab('Home')
  }

  if (!configured) return <main className="setup"><div className="brand-mark">A</div><h1>AIRGRAM setup required</h1><p>Add <code>VITE_SUPABASE_URL</code> and <code>VITE_SUPABASE_ANON_KEY</code> to the Vercel project environment variables, then redeploy.</p></main>

  if (!session) return <main className="auth-shell">
    <section className="auth-art">
      <div className="brand"><span className="brand-mark">A</span><span>AIRGRAM</span></div>
      <div className="hero-copy"><p className="eyebrow">YOUR WORLD. YOUR PEOPLE.</p><h1>Make moments<br/><span>mean more.</span></h1><p className="muted">A place for your people, your creativity and everything worth sharing.</p><div className="orbit orbit-one"></div><div className="orbit orbit-two"></div><div className="glow-ball"></div></div>
      <p className="footnote">ANI STUDIO · AIRGRAM WEB</p>
    </section>
    <section className="auth-panel">
      <div className="auth-card">
        <div className="mobile-brand"><span className="brand-mark">A</span><b>AIRGRAM</b></div>
        <p className="eyebrow">{authMode === 'signup' ? 'JOIN THE COMMUNITY' : authMode === 'reset' ? 'ACCOUNT RECOVERY' : 'WELCOME BACK'}</p>
        <h2>{authMode === 'signup' ? 'Create your space.' : authMode === 'reset' ? 'Reset password.' : 'Good to see you.'}</h2>
        <p className="muted">{authMode === 'signup' ? 'Your next chapter starts here.' : authMode === 'reset' ? 'We will send you a secure reset link.' : 'Sign in and catch up with your people.'}</p>
        <form onSubmit={submitAuth} className="form">
          {authMode === 'signup' && <label>Display name<input value={displayName} onChange={e=>setDisplayName(e.target.value)} placeholder="Your name" maxLength="80" required /></label>}
          <label>Email address<input type="email" value={email} onChange={e=>setEmail(e.target.value)} placeholder="you@example.com" autoComplete="email" required /></label>
          {authMode !== 'reset' && <label>Password<input type="password" value={password} onChange={e=>setPassword(e.target.value)} placeholder="At least 6 characters" minLength="6" autoComplete={authMode==='signup'?'new-password':'current-password'} required /></label>}
          <button className="primary-btn" disabled={busy}>{busy ? 'PLEASE WAIT…' : authMode === 'signup' ? 'CREATE ACCOUNT' : authMode === 'reset' ? 'SEND RESET LINK' : 'SIGN IN'} <span>↗</span></button>
        </form>
        {error && <div className="alert error">{error}</div>}
        {notice && <div className="alert success">{notice}</div>}
        <div className="auth-links">
          {authMode === 'login' ? <><button onClick={()=>setAuthMode('signup')}>Create account</button><button onClick={()=>setAuthMode('reset')}>Forgot password?</button></> : <button onClick={()=>{setAuthMode('login');setError('');setNotice('')}}>← Back to sign in</button>}
        </div>
        <p className="legal">By continuing, you agree to use AIRGRAM respectfully and keep your account secure.</p>
      </div>
    </section>
  </main>

  return <div className="app-shell">
    <aside className="sidebar">
      <div className="brand"><span className="brand-mark">A</span><span>AIRGRAM</span></div>
      <nav>{[['Home','⌂'],['Explore','⌕'],['Create','＋'],['Reels','▷'],['Messages','✉'],['Profile','◉']].map(([name,icon])=><button key={name} className={tab===name?'active':''} onClick={()=>setTab(name)}><span>{icon}</span>{name}</button>)}</nav>
      <div className="side-bottom"><div className="mini-user"><div className="avatar">{(profile?.display_name||email||'A').slice(0,1).toUpperCase()}</div><div><b>{profile?.display_name||session.user.email}</b><small>@{profile?.username||'creator'}</small></div></div><button className="logout" onClick={signOut}>Sign out ↗</button></div>
    </aside>
    <main className="main-content">
      <header className="topbar"><div className="mobile-brand"><span className="brand-mark">A</span><b>AIRGRAM</b></div><div className="top-pill">✦ &nbsp; YOUR WORLD. YOUR PEOPLE.</div><button className="avatar top-avatar" onClick={()=>setTab('Profile')}>{(profile?.display_name||'A').slice(0,1).toUpperCase()}</button></header>
      {notice && <div className="alert success global-alert">{notice}<button onClick={()=>setNotice('')}>×</button></div>}
      {error && <div className="alert error global-alert">{error}<button onClick={()=>setError('')}>×</button></div>}
      {tab === 'Create' ? <section className="content-column"><div className="section-heading"><p className="eyebrow">CREATE SOMETHING</p><h1>Share a moment.</h1><p className="muted">Start with a thought. Photos and video uploads are next.</p></div><form className="composer card" onSubmit={publish}><div className="composer-head"><div className="avatar">{(profile?.display_name||'A').slice(0,1).toUpperCase()}</div><b>{profile?.display_name||'Your profile'}</b><span className="public-tag">PUBLIC</span></div><textarea value={caption} onChange={e=>setCaption(e.target.value)} maxLength="2200" placeholder="What's happening in your world?" required/><div className="composer-foot"><span>{caption.length}/2200</span><button className="primary-btn" disabled={busy||!caption.trim()}>PUBLISH POST ↗</button></div></form></section>
      : tab === 'Profile' ? <section className="content-column"><div className="section-heading"><p className="eyebrow">YOUR SPACE</p><h1>Your profile.</h1></div><div className="profile-card card"><div className="profile-avatar">{(profile?.display_name||'A').slice(0,1).toUpperCase()}</div><h2>{profile?.display_name||'AIRGRAM creator'}</h2><p className="muted">@{profile?.username||'creator'}</p><p>{profile?.bio||'Your story is still being written.'}</p><div className="stats"><div><b>{posts.filter(p=>p.author_id===session.user.id).length}</b><small>Posts loaded</small></div><div><b>—</b><small>Followers</small></div><div><b>—</b><small>Following</small></div></div><button className="outline-btn" onClick={signOut}>Sign out</button></div></section>
      : <section className="content-column"><div className="section-heading"><p className="eyebrow">{tab==='Home'?'THE LATEST':'FIND YOUR PEOPLE'}</p><h1>{tab==='Home'?'Your feed.':'Explore AIRGRAM.'}</h1><p className="muted">{tab==='Home'?'A little inspiration from your corner of the world.':'Discover what creators are sharing.'}</p></div><div className="stories-strip"><div className="story-bubble add-story">＋</div><div><b>Your story</b><small>Coming soon</small></div><div className="story-note">STORIES · IN THE WORKS</div></div><div className="feed-head"><b>{tab==='Home'?'Fresh from AIRGRAM':'Public posts'}</b><button onClick={loadFeed}>↻ Refresh</button></div>
        {posts.length===0 ? <div className="empty card"><div className="empty-icon">✧</div><h2>It starts with a post.</h2><p className="muted">Be the first to share something with your community.</p><button className="primary-btn" onClick={()=>setTab('Create')}>CREATE A POST ↗</button></div> : posts.map(post=><article className="post card" key={post.id}><div className="post-head"><div className="avatar">{(post.author?.display_name||post.author?.username||'A').slice(0,1).toUpperCase()}</div><div className="post-author"><b>{post.author?.display_name||'AIRGRAM creator'}</b><small>@{post.author?.username||'creator'} · {new Date(post.created_at).toLocaleDateString()}</small></div><button className="more">•••</button></div><p className="post-caption">{post.caption}</p><div className="post-actions"><button className={post.liked?'liked':''} onClick={()=>toggleLike(post)}>{post.liked?'♥':'♡'} <span>{post.likes}</span></button><span>◌ &nbsp; Comments</span><span className="push-right">↗ Share</span></div></article>)}
      </section>}
      <footer className="app-footer">AIRGRAM WEB <span>·</span> BUILT BY ANI STUDIO <span>·</span> YOUR WORLD. YOUR PEOPLE.</footer>
    </main>
    <button className="mobile-create" onClick={()=>setTab('Create')}>＋</button>
  </div>
}

createRoot(document.getElementById('root')).render(<App />)
