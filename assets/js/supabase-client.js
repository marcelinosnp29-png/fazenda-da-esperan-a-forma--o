// Supabase Client — Compartilhado entre todas as páginas
// INSTRUÇÃO: substitua os valores abaixo pelas suas credenciais Supabase

const SUPABASE_URL  = 'COLE_SUA_URL_AQUI';
const SUPABASE_KEY  = 'COLE_SUA_CHAVE_ANON_AQUI';

let _sb;
function getSupabase() {
    if (!_sb) _sb = supabase.createClient(SUPABASE_URL, SUPABASE_KEY);
    return _sb;
}

async function getSession()  { return (await getSupabase().auth.getSession()).data.session; }
async function getUser()     { return (await getSupabase().auth.getUser()).data.user; }
async function logout()      { await getSupabase().auth.signOut(); location.href = '/admin/index.html'; }
async function login(email, senha) {
    return await getSupabase().auth.signInWithPassword({ email, password: senha });
}

async function salvarLead(lead) { return await getSupabase().from('leads').insert([lead]); }
async function listarLeads(pag=0, lim=20) {
    return await getSupabase().from('leads').select('*')
        .order('created_at', { ascending: false })
        .range(pag*lim, (pag+1)*lim-1);
}
async function atualizarLead(id, dados) {
    return await getSupabase().from('leads').update(dados).eq('id', id);
}
async function listarPosts(apenasPublicados=true) {
    let q = getSupabase().from('posts').select('*').order('created_at', { ascending: false });
    if (apenasPublicados) q = q.eq('status', 'publicado');
    return await q;
}
async function salvarPost(post) {
    if (post.id) return await getSupabase().from('posts').update(post).eq('id', post.id);
    return await getSupabase().from('posts').insert([post]);
}
async function getConfig(chave) {
    const { data } = await getSupabase().from('configuracoes').select('valor').eq('chave', chave).single();
    return data?.valor;
}
async function setConfig(chave, valor) {
    return await getSupabase().from('configuracoes')
        .upsert({ chave, valor, updated_at: new Date().toISOString() });
}
function slugify(t) {
    return t.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g,'')
        .replace(/[^a-z0-9 ]/g,'').replace(/\s+/g,'-');
}
function formatarData(iso) {
    return new Date(iso).toLocaleDateString('pt-BR',{day:'2-digit',month:'2-digit',year:'numeric'});
}
function exportarCSV(dados, nome) {
    const keys = Object.keys(dados[0]||{});
    const csv = [keys.join(','),...dados.map(r=>keys.map(k=>JSON.stringify(r[k]??'')).join(','))].join('\n');
    const a = document.createElement('a');
    a.href = 'data:text/csv;charset=utf-8,'+encodeURIComponent(csv);
    a.download = nome+'.csv'; a.click();
}
