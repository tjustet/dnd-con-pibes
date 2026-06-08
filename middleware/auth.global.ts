export default defineNuxtRouteMiddleware((to, from) => {
    const user = useSupabaseUser()
  
    // Si el usuario no está logueado e intenta ir a cualquier lado que NO sea el index (login)
    if (!user.value && to.path !== '/') {
      return navigateTo('/')
    }
  
    // Si el usuario YA está logueado e intenta entrar al index (login)
    if (user.value && to.path === '/') {
      return navigateTo('/dashboard')
    }
  })