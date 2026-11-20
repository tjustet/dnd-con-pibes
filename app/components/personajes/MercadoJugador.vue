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
    const { data, error } = await db.from('campaigns').select('mesa_estado').eq('id', props.pj.campaign_id).single()
    if (!vigente || ocupado.value || lectura !== version || error) return
    const mesa = data?.mesa_estado || {}
    const catalogo = mesa.tiendaVisible
    const permitida = catalogo && (catalogo.targets == null || catalogo.targets === 'all' || catalogo.targets.includes(props.pj.id))
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

async function cambiarCarrito(lineas, estado) {
  if (ocupado.value || pendiente.value || !tienda.value?.id) return
  ocupado.value = true
  version++
  const tiendaActual = tienda.value
  const id = idOperacion()
  try {
    const nuevo = { id, estado, tienda: tiendaActual.id, sesion: tiendaActual.sesion, items: lineas,
      total: lineas.reduce((s, i) => s + i.precio * i.unidades, 0) }
    const previo = pedido.value?.id
    await actualizarCampana(db, props.pj.campaign_id, 'mesa_estado', valor => {
      const mesa = estadoInicial(valor)
      if (mesa.tiendaVisible?.sesion !== nuevo.sesion || mesa.carritos[props.pj.id]?.id !== previo)
        throw new Error('El catálogo o el pedido cambió. Volvé a intentarlo.')
      mesa.carritos[props.pj.id] = nuevo
      return mesa
    })
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

async function pedirAyuda(id) {
  if (!canal || !pedido.value || !total.value) return
  const resultado = await canal.send({ type: 'broadcast', event: 'auxilio_financiero', payload: {
    para: id, de: props.pj.id, nombre: props.pj.nombre_pj, pedido: pedido.value.id, monto: total.value
  } })
  avisar(resultado === 'ok' ? 'Solicitud enviada.' : 'No se pudo enviar la solicitud.', resultado !== 'ok')
}

async function recibirAyuda({ payload }) {
  if (!vigente || payload.para !== props.pj.id || bloqueados.value.includes(payload.de)) return
  const monto = Number(payload.monto)
  if (!Number.isSafeInteger(monto) || monto <= 0 || monto > saldo.value) return
  if (!confirm(`¿Pagar hasta ${monto} pc por el pedido de ${payload.nombre} cuando lo apruebe el DM?`)) return
  try {
    const { error } = await db.from('dnd_aportes').insert({ campana: props.pj.campaign_id,
      personaje: props.pj.id, beneficiario: payload.de, pedido: payload.pedido, maximo: monto })
    if (error && error.code !== '23505') throw error
    await actualizarCampana(db, props.pj.campaign_id, 'mesa_estado', valor => {
      const cart = valor?.carritos?.[payload.de]
      if (cart?.id !== payload.pedido || cart.total !== monto || cart.estado !== 'comprando')
        throw new Error('El pedido ya cambió.')
      cart.estado = 'pagando'
      cart.patrocinador = props.pj.id
      return valor
    })
    avisar('Ayuda autorizada. El pedido está en la mesa del DM.')
  } catch (e) { avisar(e.message, true) }
}

onMounted(async () => {
  if (!props.pj.campaign_id || props.esNuevo) return
  canal = db.channel('partida_' + props.pj.campaign_id).on('broadcast', { event: 'auxilio_financiero' }, recibirAyuda).subscribe()
  timer = setInterval(refrescar, 2000)
  void refrescar()
  const { data } = await db.from('characters').select('id,nombre_pj').eq('campaign_id', props.pj.campaign_id)
    .eq('tipo', 'pj').neq('id', props.pj.id)
  if (vigente) companeros.value = data || []
})
onBeforeUnmount(() => {
  vigente = false
  clearInterval(timer)
  if (canal) db.removeChannel(canal)
})
</script>

<template>
  <aside v-if="tienda" class="mercado-pj" aria-label="Tienda proyectada">
    <button class="abrir-tienda" :aria-expanded="visible" @click="visible = !visible">🛒 {{ tienda.nombre }} · {{ visible ? 'Ocultar' : 'Abrir' }}</button>
    <div v-if="visible" class="contenido-mercado">
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
        <details v-if="!pendiente && companeros.length"><summary>Pedir ayuda a un compañero</summary>
          <button v-for="c in companeros" :key="c.id" @click="pedirAyuda(c.id)">{{ c.nombre_pj }}</button>
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
</style>
