export default defineNuxtRouteMiddleware(async to => {
  const db = useSupabaseClient()
  const { data: { user } } = await db.auth.getUser()
  if (!user) return navigateTo('/')
  const { data: campana, error } = await db.from('campaigns').select('dm_id').eq('id', to.params.id).maybeSingle()
  if (error) throw createError({ statusCode: 503, statusMessage: 'No se pudo verificar la campaña' })
  if (campana?.dm_id === user.id) return
  if (campana && user.email) {
    const { data, error: errorPerfil } = await db.from('profiles').select('id').eq('id', campana.dm_id).eq('email', user.email).maybeSingle()
    if (errorPerfil) throw createError({ statusCode: 503, statusMessage: 'No se pudo verificar el perfil' })
    if (data) return
  }
  return navigateTo('/dashboard')
})
