<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'

const props = defineProps({
  pj: { type: Object, required: true },
  esNuevo: { type: Boolean, default: false }
})

const supabase = useSupabaseClient()

const tiendaAbierta = ref(false)
const catalogoTienda = ref([])
const nombreTienda = ref('')
const miCarrito = ref([]) 
const compañerosMesa = ref([]) 
const pidesBloqueados = ref([]) 

const totalCobrePropio = computed(() => {
  const m = props.pj.monedas || { ppt: 0, po: 0, plata: 0, pc: 0 }
  return (m.ppt * 10000) + (m.po * 1000) + (m.plata * 100) + m.pc
})

const totalCarritoCobre = computed(() => {
  return miCarrito.value.reduce((acc, it) => acc + (it.precio_dm ?? it.precio_original), 0)
})

const refrescarTiendaYCarrito = async () => {
  if (!props.pj.campaign_id || props.esNuevo) return
  
  const { data: camp } = await supabase.from('campaigns').select('mesa_estado').eq('id', props.pj.campaign_id).single()
  if (camp?.mesa_estado) {
    const tv = camp.mesa_estado.tiendaVisible
    if (tv && (tv.targets === 'all' || tv.targets.includes(props.pj.id))) {
      tiendaAbierta.value = true
      nombreTienda.value = tv.nombre
      catalogoTienda.value = tv.inventario
    } else {
      tiendaAbierta.value = false
    }

    const miC = camp.mesa_estado.carritos?.[props.pj.id]
    if (miC) {
      miCarrito.value = miC.items
      if (miC.estado === 'rechazado') { alert("❌ El vendedor rechazó tu oferta o no tienes fondos."); limpiarCarritoLocal() }
      if (miC.estado === 'aprobado') { alert("⚔️ ¡Compra aprobada! Artículos añadidos al inventario."); limpiarCarritoLocal(); tiendaAbierta.value = false }
    }
  }
}

let bucleTienda = null
onMounted(async () => {
  bucleTienda = setInterval(refrescarTiendaYCarrito, 2000)
  
  setTimeout(async () => {
    if(props.pj.campaign_id) {
      const { data } = await supabase.from('characters').select('id, nombre_pj').eq('campaign_id', props.pj.campaign_id).neq('id', props.pj.id)
      if (data) compañerosMesa.value = data
    }
  }, 3000)

  supabase.channel('partida_' + props.pj.campaign_id)
    .on('broadcast', { event: 'auxilio_financiero' }, async (payload) => {
      if (payload.payload.paraId === props.pj.id && !pidesBloqueados.value.includes(payload.payload.deId)) {
        const aceptar = confirm(`🙏 ${payload.payload.deNombre} necesita ayuda para comprar y te pide ${payload.payload.monto} monedas de cobre. ¿Deseas pagar por él?`)
        if (aceptar) {
          emitirPagoCompañero(payload.payload.deId, payload.payload.monto)
        } else {
          alert("Petición rechazada silenciosamente.")
        }
      }
    }).subscribe()
})

onUnmounted(() => { clearInterval(bucleTienda) })

const meterAlCarrito = async (item) => {
  miCarrito.value.push({ id: item.id, nombre: item.nombre, precio_original: item.valor_cobre, precio_dm: item.valor_cobre, peso: item.peso, bono: item.bono })
  notificarCarritoMesa('comprando')
}

const removerDelCarrito = (idx) => {
  miCarrito.value.splice(idx, 1)
  if (miCarrito.value.length === 0) limpiarCarritoLocal()
  else notificarCarritoMesa('comprando')
}

const limpiarCarritoLocal = () => { miCarrito.value = [] }

const notificarCarritoMesa = async (estado) => {
  const { data } = await supabase.from('campaigns').select('mesa_estado').eq('id', props.pj.campaign_id).single()
  const mEst = data?.mesa_estado || {}
  if (!mEst.carritos) mEst.carritos = {}
  mEst.carritos[props.pj.id] = { estado: estado, total: totalCarritoCobre.value, items: miCarrito.value }
  await supabase.from('campaigns').update({ mesa_estado: mEst }).eq('id', props.pj.campaign_id)
}

const solicitarAprobacionDM = () => {
  if (totalCobrePropio.value < totalCarritoCobre.value) return alert("No tienes suficientes monedas en la bolsa.")
  notificarCarritoMesa('pagando')
}

const rogarPorMonedas = (compañeroId) => {
  if (totalCarritoCobre.value === 0) return alert("Tu carrito está vacío.")
  supabase.channel('partida_' + props.pj.campaign_id).send({
    type: 'broadcast', event: 'auxilio_financiero',
    payload: { deId: props.pj.id, deNombre: props.pj.nombre_pj, paraId: compañeroId, monto: totalCarritoCobre.value }
  })
  alert("Mensaje enviado por telepatía. Esperando respuesta de tu camarada...")
}

const emitirPagoCompañero = async (solicitanteId, montoCobre) => {
  if (totalCobrePropio.value < montoCobre) return alert("¡No tienes fondos suficientes para salvarlo!")

  let miResto = totalCobrePropio.value - montoCobre
  const nPpt = Math.floor(miResto / 10000); miResto %= 10000;
  const nPo = Math.floor(miResto / 1000); miResto %= 1000;
  const nPlata = Math.floor(miResto / 100); miResto %= 100;
  
  await supabase.from('characters').update({ monedas: { ppt: nPpt, po: nPo, plata: nPlata, pc: miResto } }).eq('id', props.pj.id)
  props.pj.monedas = { ppt: nPpt, po: nPo, plata: nPlata, pc: miResto } 

  const { data } = await supabase.from('campaigns').select('mesa_estado').eq('id', props.pj.campaign_id).single()
  if (data?.mesa_estado?.carritos?.[solicitanteId]) {
    data.mesa_estado.carritos[solicitanteId].estado = 'pagando'
    await supabase.from('campaigns').update({ mesa_estado: data.mesa_estado }).eq('id', props.pj.campaign_id)
    alert("¡Fondos transferidos! El DM procesará los artículos ahora.")
  }
}

const toggleBloqueoCompañero = (id) => {
  if (pidesBloqueados.value.includes(id)) {
    pidesBloqueados.value = pidesBloqueados.value.filter(b => b !== id)
  } else {
    pidesBloqueados.value.push(id)
  }
}
</script>

<template>
  <div v-if="tiendaAbierta" class="panel-tienda-pj">
      <div class="t-header">
        <h3>🛒 {{ nombreTienda }}</h3>
        <button @click="tiendaAbierta = false" class="btn-cerrar-t">Ocultar</button>
      </div>
      <div class="t-bolsa">
        <span class="oro">💰 Tienes: {{ pj.monedas?.po || 0 }} po | {{ pj.monedas?.plata || 0 }} pp | {{ pj.monedas?.pc || 0 }} pc</span>
      </div>
      <div class="t-catalogo">
        <div v-for="item in catalogoTienda" :key="item.id" class="t-item">
          <div class="i-info">
            <strong>{{ item.nombre }}</strong>
            <span>{{ item.bono }}</span>
          </div>
          <button @click="meterAlCarrito(item)" class="btn-add">Añadir</button>
        </div>
      </div>
      <div class="t-carrito" v-if="miCarrito.length > 0">
        <h4>Tu Selección:</h4>
        <div v-for="(it, idx) in miCarrito" :key="idx" class="c-fila">
          <span>{{ it.nombre }}</span>
          <button @click="removerDelCarrito(idx)">❌</button>
        </div>
        <div class="c-total">Total a pagar (DM): {{ totalCarritoCobre }} pc</div>
        <button @click="solicitarAprobacionDM" class="btn-pagar" :disabled="totalCobrePropio < totalCarritoCobre">💰 OFRECER PAGO AL DM</button>
        <button class="btn-pedir" @click="rogarPorMonedas('id_de_otro')">🙏 Pedir a compañero</button>
      </div>
  </div>

  <div v-if="tiendaAbierta" class="mercado-flotante-pj">
      <div class="mercado-head">
        <h4>🛒 Vista: {{ nombreTienda }}</h4>
        <button @click="tiendaAbierta = false" class="btn-ocultar">Ocultar</button>
      </div>

      <div class="mercado-cuerpo">
        <div v-for="item in catalogoTienda" :key="item.id" class="mercado-row">
          <div class="m-info">
            <strong>{{ item.nombre }}</strong>
            <small>{{ item.bono || 'Sin magia' }}</small>
          </div>
          <button @click="meterAlCarrito(item)" class="btn-comprar-add">+</button>
        </div>
      </div>

      <div class="mercado-pie" v-if="miCarrito.length > 0">
        <h5>Tu Carrito:</h5>
        <div class="mini-lista-cart">
          <div v-for="(it, idx) in miCarrito" :key="idx" class="cart-pj-row">
            <span>{{ it.nombre }}</span>
            <button @click="removerDelCarrito(idx)">❌</button>
          </div>
        </div>
        <div class="cart-total-info">Total: <strong>{{ totalCarritoCobre }} pc</strong></div>
        
        <button @click="solicitarAprobacionDM" class="btn-enviar-caja" :disabled="totalCobrePropio < totalCarritoCobre">
          💰 ENVIAR PAGO AL DM
        </button>

        <div class="zona-auxilio" v-if="compañerosMesa.length > 0">
          <label class="lbl-aux">Pedir ayuda a camarada:</label>
          <div class="lista-companeros-p2p">
            <button v-for="comp in compañerosMesa" :key="comp.id" @click="rogarPorMonedas(comp.id)" class="btn-rogar">
              🙏 {{ comp.nombre_pj }}
            </button>
          </div>
        </div>
      </div>

      <div class="antispam-box" v-if="compañerosMesa.length > 0">
        <h5>Seguridad (Anti-Spam)</h5>
        <div class="lista-antispam">
          <label v-for="comp in compañerosMesa" :key="comp.id" class="lbl-spam">
            <input type="checkbox" :checked="pidesBloqueados.includes(comp.id)" @change="toggleBloqueoCompañero(comp.id)" />
            <span>Bloquear peticiones de {{ comp.nombre_pj }}</span>
          </label>
        </div>
      </div>
  </div>
</template>

<style scoped>
@import url('https://fonts.googleapis.com/css2?family=Cinzel:wght@600;700&family=Inter:wght@400;600&display=swap');

.panel-tienda-pj { position: fixed; right: 20px; top: 100px; width: 320px; background: #0a0a0c; border: 2px solid #b45309; border-radius: 12px; z-index: 100; box-shadow: -5px 10px 30px rgba(0,0,0,0.8); display: flex; flex-direction: column; max-height: 80vh; }
.t-header { background: #b45309; color: white; padding: 1rem; display: flex; justify-content: space-between; border-radius: 10px 10px 0 0; }
.t-header h3 { margin: 0; font-family: 'Cinzel', serif; }
.t-bolsa { padding: 0.8rem; background: #111; text-align: center; font-weight: bold; border-bottom: 1px solid #334155; color: #facc15; }
.t-catalogo { flex-grow: 1; overflow-y: auto; padding: 0.5rem; }
.t-item { display: flex; justify-content: space-between; background: #1a1a1f; padding: 0.8rem; margin-bottom: 0.5rem; border-radius: 6px; border: 1px solid #334155; }
.i-info { display: flex; flex-direction: column; color: white; font-size: 0.9rem; }
.i-info span { font-size: 0.8rem; color: #94a3b8; }
.btn-add { background: #166534; color: white; border: none; border-radius: 4px; padding: 0.3rem 0.6rem; cursor: pointer; }
.t-carrito { background: #111; padding: 1rem; border-top: 2px dashed #b45309; border-radius: 0 0 10px 10px; }
.c-fila { display: flex; justify-content: space-between; color: #cbd5e1; font-size: 0.9rem; margin-bottom: 0.3rem; }
.c-total { font-weight: bold; color: #4ade80; text-align: right; margin: 1rem 0; }
.btn-pagar { width: 100%; background: #ca8a04; color: white; border: none; padding: 0.8rem; border-radius: 6px; font-weight: bold; cursor: pointer; }
.btn-pagar:disabled { background: #475569; cursor: not-allowed; }
.btn-pedir { width: 100%; background: transparent; color: #60a5fa; border: 1px dashed #60a5fa; padding: 0.5rem; margin-top: 0.5rem; cursor: pointer; }

/* MERCADO JUGADOR FLOTANTE */
.mercado-flotante-pj { position: fixed; bottom: 20px; right: 20px; width: 340px; background: #0a0a0c; border: 2px solid #b45309; border-radius: 12px; z-index: 9999; box-shadow: 0 10px 30px rgba(0,0,0,0.8); display: flex; flex-direction: column; max-height: 80vh; }
.mercado-head { background: #b45309; color: white; padding: 0.8rem; display: flex; justify-content: space-between; align-items: center; border-radius: 10px 10px 0 0; }
.mercado-head h4 { margin: 0; font-family: 'Cinzel', serif; }
.btn-ocultar { background: rgba(0,0,0,0.3); border: none; color: white; padding: 0.2rem 0.5rem; border-radius: 4px; cursor: pointer; }
.mercado-cuerpo { padding: 0.5rem; overflow-y: auto; flex-grow: 1; display: flex; flex-direction: column; gap: 0.4rem; }
.mercado-row { display: flex; justify-content: space-between; align-items: center; background: #111; padding: 0.6rem; border-radius: 6px; border: 1px solid #27272a; }
.m-info { display: flex; flex-direction: column; }
.m-info strong { color: white; font-size: 0.9rem; }
.m-info small { color: #a78bfa; font-size: 0.75rem; }
.btn-comprar-add { background: #15803d; color: white; border: none; border-radius: 4px; width: 28px; height: 28px; font-weight: bold; cursor: pointer; }
.mercado-pie { background: #111; padding: 1rem; border-top: 2px dashed #b45309; }
.mini-lista-cart { max-height: 100px; overflow-y: auto; margin-bottom: 0.5rem; }
.cart-pj-row { display: flex; justify-content: space-between; font-size: 0.85rem; color: #cbd5e1; margin-bottom: 0.2rem; }
.cart-pj-row button { background: transparent; border: none; cursor: pointer; }
.cart-total-info { text-align: right; margin-bottom: 0.8rem; color: #94a3b8; }
.cart-total-info strong { color: #4ade80; font-size: 1.1rem; }
.btn-enviar-caja { width: 100%; background: #eab308; color: black; border: none; padding: 0.6rem; border-radius: 6px; font-weight: bold; cursor: pointer; }
.btn-enviar-caja:disabled { background: #475569; color: #94a3b8; cursor: not-allowed; }
.zona-auxilio { margin-top: 0.8rem; border-top: 1px dashed #334155; padding-top: 0.5rem; }
.lbl-aux { font-size: 0.75rem; color: #94a3b8; font-weight: bold; display: block; margin-bottom: 0.3rem; }
.lista-companeros-p2p { display: flex; flex-wrap: wrap; gap: 0.4rem; max-height: 80px; overflow-y: auto; }
.btn-rogar { background: #1e293b; border: 1px solid #3b82f6; color: #93c5fd; padding: 0.3rem 0.5rem; border-radius: 4px; font-size: 0.75rem; cursor: pointer; }
.antispam-box { background: #050507; padding: 0.6rem; border-top: 1px solid #27272a; border-radius: 0 0 10px 10px; }
.antispam-box h5 { margin: 0 0 0.4rem 0; font-size: 0.75rem; color: #ef4444; text-transform: uppercase; }
.lista-antispam { max-height: 70px; overflow-y: auto; }
.lbl-spam { display: flex; align-items: center; gap: 0.5rem; font-size: 0.7rem; color: #94a3b8; margin-bottom: 0.2rem; cursor: pointer; }
.lbl-spam input { accent-color: #ef4444; }
</style>