<script setup>
const props = defineProps({ pj: { type: Object, required: true }, esNuevo: Boolean })
const db = useSupabaseClient()
const { avisar } = useAvisos()
const tienda = ref(null)
const visible = ref(true)
const items = ref([])
const pedido = ref(null)
const companeros = ref([])
const bloqueados = ref([])
const ocupado = ref(false)
const total = computed(() => items.value.reduce((s, i) => s + i.precio * i.unidades, 0))
const pendiente = computed(() => pedido.value?.estado === 'pagando' && pedido.value?.sesion === tienda.value?.sesion)
const saldo = computed(() => cobreDe(props.pj))
const solicitudes = ref([])
const solicitudesVisibles = computed(() => solicitudes.value.filter(s => !bloqueados.value.includes(s.de)))
let canal
let timer
let vigente = true
let leyendo = false
let ultimoAviso
let version = 0

async function refrescar() {
  if (leyendo || ocupado.value || !props.pj.campaign_id) return
  const lectura = version
  leyendo = true
  try {
    const { data, error } = await db.rpc('dnd_mercado_jugador', { p_campana: props.pj.campaign_id, p_personaje: props.pj.id })
    if (!vigente || ocupado.value || lectura !== version || error) return
    const mesa = data || {}
    const catalogo = mesa.tiendaVisible
    const permitida = catalogo && (catalogo.targets == null || catalogo.targets === 'all' || catalogo.targets.includes(props.pj.id))
    solicitudes.value = Object.entries(mesa.carritos || {}).filter(([, cart]) =>
      catalogo?.id && cart?.tienda === catalogo.id && cart.sesion === catalogo.sesion &&
      cart.estado === 'comprando' && cart.ayudante === props.pj.id && cart.total > 0
    ).map(([de, cart]) => ({ de, id: cart.id, monto: cart.total }))
    const nueva = permitida ? catalogo : null
    if (nueva?.sesion !== tienda.value?.sesion || nueva?.id !== tienda.value?.id) visible.value = true
    tienda.value = nueva
    pedido.value = mesa.carritos?.[props.pj.id] ?? null
    const cart = pedido.value
    const actual = cart && cart.tienda === nueva?.id && cart.sesion === nueva?.sesion
    items.value = actual && ['comprando', 'pagando'].includes(cart.estado) ? cart.items : []
    if (cart && ['aprobado','rechazado'].includes(cart.estado) && ultimoAviso !== cart.id) {
      ultimoAviso = cart.id
      avisar(cart.estado === 'aprobado' ? 'Compra aprobada. Revisá tu inventario.' : 'El DM rechazó el pedido.')
    }
  } finally { leyendo = false }
}

async function cambiarCarrito(lineas, estado, ayudante = null) {
  if (ocupado.value || pendiente.value || !tienda.value?.id) return
  ocupado.value = true
  version++
  const tiendaActual = tienda.value
  const id = idOperacion()
  try {
    const nuevo = { id, estado, ayudante, tienda: tiendaActual.id, sesion: tiendaActual.sesion, items: lineas,
      total: lineas.reduce((s, i) => s + i.precio * i.unidades, 0) }
    const { error } = await db.rpc('dnd_pedido', { p_campana: props.pj.campaign_id, p_personaje: props.pj.id,
      p_previo: pedido.value ? { id: pedido.value.id, estado: pedido.value.estado } : null, p_nuevo: nuevo })
    if (error) throw error

    items.value = lineas
    pedido.value = nuevo
  } catch (e) { avisar(e.message, true) }
  finally { ocupado.value = false }
}

function agregar(item) {
  const lineas = items.value.map(i => ({ ...i }))
  const fila = lineas.find(i => i.item_id === item.id && i.tabla === item.tabla_origen)
  if ((fila?.unidades || 0) >= item.stock_local) return avisar('No hay más unidades disponibles.')
  if (fila) fila.unidades++
  else lineas.push({ item_id: item.id, tabla: item.tabla_origen, nombre: item.nombre, unidades: 1, precio: Number(item.precio_cobre) || 0 })
  return cambiarCarrito(lineas, 'comprando')
}

function nombreAliado(id) {
  return companeros.value.find(c => c.id === id)?.nombre_pj || 'tu compañero'
}

async function responderAyuda(solicitud, aceptar) {
  if (ocupado.value) return
  if (aceptar && saldo.value < solicitud.monto) return avisar('Tu saldo no alcanza para este pedido.', true)
  ocupado.value = true
  version++
  try {
    const { error } = await db.rpc('dnd_responder_ayuda', { p_campana: props.pj.campaign_id, p_personaje: props.pj.id,
      p_comprador: solicitud.de, p_pedido: solicitud.id, p_aceptar: aceptar })
    if (error) throw error

    avisar(aceptar ? 'Ayuda autorizada. Falta que el DM apruebe el pedido.' : 'Solicitud rechazada.')
  } catch (e) { avisar(e.message, true) }
  finally { ocupado.value = false; void refrescar() }
}

onMounted(async () => {
  if (!props.pj.campaign_id || props.esNuevo) return
  canal = db.channel('mercado_' + props.pj.id).on('postgres_changes', {
    event: 'UPDATE', schema: 'public', table: 'campana_publicada', filter: `id=eq.${props.pj.campaign_id}`
  }, refrescar).subscribe()
  timer = setInterval(refrescar, 2000)
  void refrescar()
  const { data } = await db.rpc('dnd_aliados', { p_campana: props.pj.campaign_id, p_personaje: props.pj.id })

  if (vigente) companeros.value = data || []
})
onBeforeUnmount(() => {
  vigente = false
  clearInterval(timer)
  if (canal) db.removeChannel(canal)
})
</script>

<template>
  <aside v-if="tienda || solicitudesVisibles.length" class="mercado-pj" aria-label="Tienda proyectada">
    <section v-if="solicitudesVisibles.length" class="ayudas-recibidas" aria-label="Ayuda entre aliados">
      <article v-for="solicitud in solicitudesVisibles" :key="solicitud.id">
        <p><strong>{{ nombreAliado(solicitud.de) }}</strong> te pide pagar {{ solicitud.monto }} pc por su compra.</p>
        <small>{{ saldo < solicitud.monto ? 'Tu saldo no alcanza.' : 'Se cobra cuando el DM aprueba la compra.' }}</small>
        <div>
          <button type="button" :disabled="ocupado || saldo < solicitud.monto" @click="responderAyuda(solicitud, true)">Autorizar pago</button>
          <button type="button" :disabled="ocupado" @click="responderAyuda(solicitud, false)">Rechazar</button>
        </div>
      </article>
    </section>
    <button v-if="tienda" class="abrir-tienda" :aria-expanded="visible" @click="visible = !visible">🛒 {{ tienda.nombre }} · {{ visible ? 'Ocultar' : 'Abrir' }}</button>
    <div v-if="tienda && visible" class="contenido-mercado">
      <p>Tu saldo <strong>{{ saldo }} pc</strong></p>
      <p v-if="!tienda.id">Pedile al DM que vuelva a proyectar esta tienda.</p>
      <p v-else-if="!tienda.inventario?.length">El DM todavía no reveló objetos.</p>
      <div v-for="i in tienda.inventario" :key="i.tabla_origen + ':' + i.id" class="fila-mercado">
        <div><strong>{{ i.nombre }}</strong><small>{{ i.precio_cobre }} pc · {{ i.stock_local }} disponibles</small></div>
        <button :disabled="ocupado || pendiente || !i.stock_local || !tienda.id" :aria-label="'Agregar ' + i.nombre" @click="agregar(i)">+</button>
      </div>
      <template v-if="items.length">
        <h3>Tu pedido</h3>
        <div v-for="(i, n) in items" :key="i.tabla + ':' + i.item_id" class="fila-mercado">
          {{ i.unidades }} × {{ i.nombre }}
          <button :disabled="ocupado || pendiente" :aria-label="'Quitar ' + i.nombre" @click="cambiarCarrito(items.filter((_, idx) => idx !== n), 'comprando')">×</button>
        </div>
        <button class="pagar" :disabled="ocupado || pendiente || saldo < total" @click="cambiarCarrito(items, 'pagando')">
          {{ pendiente ? 'Esperando al DM' : 'Ofrecer pago' }} · {{ total }} pc
        </button>
        <p v-if="pedido?.ayudante" class="aviso-ayuda" role="status">
          Esperando a {{ nombreAliado(pedido.ayudante) }}.
          <button type="button" :disabled="ocupado" @click="cambiarCarrito(items, 'comprando')">Cancelar solicitud</button>
        </p>
        <p v-else-if="pendiente && pedido?.patrocinador">Paga {{ nombreAliado(pedido.patrocinador) }} cuando el DM apruebe.</p>
        <p v-else-if="pedido?.ayudaRechazadaPor">{{ nombreAliado(pedido.ayudaRechazadaPor) }} rechazó la solicitud.</p>
        <details v-if="!pendiente && !pedido?.ayudante && total > 0 && companeros.length"><summary>Pedir ayuda a un compañero</summary>
          <button v-for="c in companeros" :key="c.id" :disabled="ocupado" @click="cambiarCarrito(items, 'comprando', c.id)">{{ c.nombre_pj }}</button>
        </details>
      </template>
      <details v-if="companeros.length"><summary>Solicitudes de ayuda</summary>
        <label v-for="c in companeros" :key="c.id"><input v-model="bloqueados" type="checkbox" :value="c.id"> Silenciar a {{ c.nombre_pj }}</label>
      </details>
    </div>
  </aside>
</template>

<style scoped>
.mercado-pj { position: fixed; z-index: 10000; bottom: max(12px, env(safe-area-inset-bottom)); left: 12px; max-width: calc(100vw - 24px); color: #e2e8f0; }
.abrir-tienda, .contenido-mercado { background: #111115; border: 1px solid #b45309; border-radius: 8px; }
.abrir-tienda { color: #facc15; padding: .6rem .8rem; max-width: min(19rem, 45vw); overflow: hidden; white-space: nowrap; text-overflow: ellipsis; }
.contenido-mercado { position: absolute; bottom: calc(100% + 8px); left: 0; width: min(335px, calc(100vw - 24px)); max-height: 67dvh; overflow: auto; padding: 1rem; box-shadow: 0 12px 40px #000a; }
.fila-mercado { display: flex; justify-content: space-between; align-items: center; gap: 8px; padding: 6px 0; border-bottom: 1px solid #27272a; }
.contenido-mercado :is(button,summary) { padding: 6px 9px; cursor: pointer; color: #facc15; }
.contenido-mercado small, .contenido-mercado label { display: block; color: #aab6c5; }
.pagar { width: 100%; margin: 10px 0; background: #291e0d; }
.ayudas-recibidas { max-width: min(24rem,calc(100vw - 24px)); max-height: 32dvh; overflow-y: auto; padding: .8rem; border: 1px solid #967440; border-radius: 8px; background: #201b15; }
.ayudas-recibidas p { margin: 0; }
.ayudas-recibidas small { color: #d7c8aa; }
.ayudas-recibidas button { margin: .5rem .45rem 0 0; padding: .45rem .65rem; border-radius: 5px; border: 1px solid #776349; }
.ayudas-recibidas button:first-child { color: #ffdf99; }
.ayudas-recibidas ~ .contenido-mercado { max-height: 45dvh; }
.aviso-ayuda { color: #f5d482; }
</style>
