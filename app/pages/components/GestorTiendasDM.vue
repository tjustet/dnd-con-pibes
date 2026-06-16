<script setup>
import { ref, onMounted, computed } from 'vue'

const props = defineProps({
  campaignId: { type: [String, Number], required: true },
  jugadores: { type: Array, default: () => [] },
  carritosMesa: { type: Object, default: () => ({}) }
})

const supabase = useSupabaseClient()
const emit = defineEmits(['cerrar', 'proyectarVision', 'proyectarTienda', 'actualizarCarritos', 'aprobarCompra', 'rechazarCompra'])

const lugares = ref([])
const catalogoObjetos = ref([])
const lugarSeleccionado = ref(null)
const cargando = ref(true)

const tiradaInvestigacion = ref(10)
const objetosRevelados = ref([]) 
const jugadoresDestino = ref([]) 

const cargarTiendas = async () => {
  const { data: objData } = await supabase.from('objects' in supabase ? 'objects' : 'objetos').select('*')
  if (objData) catalogoObjetos.value = objData
  const { data: lugData } = await supabase.from('lugares').select('*').eq('campaign_id', props.campaignId)
  if (lugData) lugares.value = lugData
  cargando.value = false
}

const objetosDelLugar = computed(() => {
  if (!lugarSeleccionado.value || !lugarSeleccionado.value.objetos) return []
  return catalogoObjetos.value.filter(obj => lugarSeleccionado.value.objetos.includes(obj.id))
})

// FIX: Comparación exacta de rarezas
const aplicarTiradaD20 = () => {
  const tirada = tiradaInvestigacion.value
  objetosRevelados.value = [] 
  
  objetosDelLugar.value.forEach(obj => {
    let revela = false
    const rareza = (obj.rareza || 'común').toLowerCase().trim()
    
    if (rareza === 'común' && tirada >= 4) revela = true
    else if (rareza === 'poco común' && tirada >= 10) revela = true
    else if (rareza === 'raro' && tirada >= 15) revela = true
    else if (rareza === 'épico' && tirada >= 18) revela = true
    else if (rareza === 'legendario' && tirada >= 20) revela = true

    if (revela) objetosRevelados.value.push(obj.id)
  })
}

const mostrarInventarioLugar = () => {
  const inventarioFiltrado = objetosDelLugar.value.filter(o => objetosRevelados.value.includes(o.id))
  emit('proyectarTienda', {
    nombreLugar: lugarSeleccionado.value.nombre,
    inventario: inventarioFiltrado,
    targets: jugadoresDestino.value.length > 0 ? jugadoresDestino.value : 'all'
  })
}

// Conversor universal de monedas para mostrarle al DM
const desglosarMonedas = (totalCobre) => {
  let resto = totalCobre
  const po = Math.floor(resto / 1000); resto %= 1000;
  const pp = Math.floor(resto / 100); resto %= 100;
  return `${po}po ${pp}pp ${resto}pc`
}

// Gran Total de toda la taberna junta
const granTotalMesa = computed(() => {
  return Object.values(props.carritosMesa).reduce((acc, cart) => acc + (cart.total || 0), 0)
})

const cambiarPrecioDM = (pjId, itemIdx, nuevoPrecio) => {
  const nuevosCarritos = JSON.parse(JSON.stringify(props.carritosMesa))
  nuevosCarritos[pjId].items[itemIdx].precio_dm = parseInt(nuevoPrecio) || 0
  nuevosCarritos[pjId].total = nuevosCarritos[pjId].items.reduce((acc, it) => acc + (it.precio_dm ?? it.precio_original), 0)
  emit('actualizarCarritos', nuevosCarritos)
}

onMounted(() => { cargarTiendas() })
</script>

<template>
  <div class="modal-dm-overlay" @click.self="$emit('cerrar')">
    <div class="modal-dm-sheet tienda-sheet">
      
      <div class="header-tienda-dm">
        <h3>🏪 Panel de Control de Mercaderes</h3>
        <button class="btn-cerrar" @click="$emit('cerrar')">✖</button>
      </div>

      <div v-if="cargando" class="cargando-txt">Abriendo libros contables...</div>

      <div v-else class="layout-tienda-dm">
        
        <div class="col-panel col-lugares">
          <h4 class="subtit">Asentamientos</h4>
          <div class="lista-items">
            <div v-for="lugar in lugares" :key="lugar.id" class="lugar-card" :class="{'activo': lugarSeleccionado?.id === lugar.id}" @click="lugarSeleccionado = lugar; objetosRevelados = []">
              {{ lugar.nombre }}
            </div>
          </div>
        </div>

        <div class="col-panel col-detalles" v-if="lugarSeleccionado">
          <h4 class="subtit">Estás en: {{ lugarSeleccionado.nombre }}</h4>
          
          <div class="zona-dado">
            <label class="lbl-grupo">Resultado de Dados (Investigación):</label>
            <div class="dado-flex">
              <input type="number" v-model="tiradaInvestigacion" class="input-dado" min="1" max="40" />
              <button @click="aplicarTiradaD20" class="btn-evaluar">Filtrar por Tabla</button>
            </div>
          </div>

          <div class="lista-inventario-check mt-1">
            <label v-for="obj in objetosDelLugar" :key="obj.id" class="item-check">
              <input type="checkbox" :value="obj.id" v-model="objetosRevelados">
              <span :class="'rareza-' + (obj.rareza || '').split(' ')[0].toLowerCase()">
                {{ obj.nombre }} ({{ obj.rareza }}) — {{ desglosarMonedas(obj.valor_cobre) }}
              </span>
            </label>
          </div>

          <div class="zona-targets mt-1">
            <label class="lbl-grupo">¿Quiénes ven esta mercadería?</label>
            <div class="jugadores-checks">
              <label class="item-check">
                <input type="checkbox" value="all" @change="jugadoresDestino = []" :checked="jugadoresDestino.length === 0"> 
                <span>📢 Toda la mesa</span>
              </label>
              <label v-for="pj in jugadores" :key="pj.id" class="item-check">
                <input type="checkbox" :value="pj.id" v-model="jugadoresDestino"> 
                <span>{{ pj.nombre_pj }}</span>
              </label>
            </div>
          </div>

          <button @click="mostrarInventarioLugar" class="btn-proyectar-oferta mt-1">
            👁️ Forzar Vista a los Elegidos
          </button>
        </div>
        <div v-else class="col-panel col-detalles vacio">Selecciona una tienda del mapa izquierdo.</div>

        <div class="col-panel col-carritos">
          <h4 class="subtit">Carritos Activos</h4>
          <div class="carritos-lista">
            
            <div v-for="(cart, pjId) in carritosMesa" :key="pjId" class="carrito-box" v-show="cart.items.length > 0">
              <div class="c-head">
                <strong>{{ jugadores.find(j => j.id === pjId)?.nombre_pj || 'Héroe' }}</strong>
                <span class="c-estado" :class="cart.estado">
                  {{ cart.estado === 'pagando' ? '💰 Pagando...' : '🛒 Armándolo' }}
                </span>
              </div>
              
              <div v-for="(it, idx) in cart.items" :key="idx" class="c-item">
                <span class="c-nom">{{ it.nombre }}</span>
                <div class="c-precio-edit">
                  <input type="number" :value="it.precio_dm ?? it.precio_original" @change="e => cambiarPrecioDM(pjId, idx, e.target.value)" />
                  <span>pc</span>
                </div>
              </div>

              <div class="c-total">Subtotal: {{ desglosarMonedas(cart.total) }}</div>

              <div class="c-acciones" v-if="cart.estado === 'pagando'">
                <button class="btn-rechazar" @click="$emit('rechazarCompra', pjId)">Rechazar</button>
                <button class="btn-aprobar" @click="$emit('aprobarCompra', pjId)">Aceptar</button>
              </div>
            </div>

            <div v-if="Object.keys(carritosMesa).length === 0" class="txt-vacio">Ningún aventurero cargó ítems.</div>
          </div>

          <div class="caja-registradora-total" v-if="granTotalMesa > 0">
            <span>Recaudación Total Esperada:</span>
            <strong>{{ desglosarMonedas(granTotalMesa) }}</strong>
          </div>
        </div>

      </div>
    </div>
  </div>
</template>

<style scoped>
.modal-dm-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.85); display: flex; align-items: center; justify-content: center; z-index: 99999; padding: 1rem; }
.tienda-sheet { width: 95%; max-width: 1250px; height: 85vh; display: flex; flex-direction: column; background: #0a0a0c; border: 2px solid #3b82f6; border-radius: 12px; box-shadow: 0 0 40px rgba(0,0,0,0.9); }
.header-tienda-dm { display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #1e293b; padding: 1rem 1.5rem; }
.header-tienda-dm h3 { font-family: 'Cinzel', serif; color: #facc15; margin: 0; font-size: 1.4rem; }
.btn-cerrar { background: transparent; border: none; color: #94a3b8; font-size: 1.5rem; cursor: pointer; }

.layout-tienda-dm { display: grid; grid-template-columns: 240px 1fr 380px; gap: 1.5rem; flex-grow: 1; overflow: hidden; padding: 0 1.5rem 1.5rem 1.5rem; }
.col-panel { display: flex; flex-direction: column; overflow-y: auto; padding-right: 0.4rem; }
.col-lugares { border-right: 1px solid #1e293b; }
.col-carritos { border-left: 1px solid #1e293b; padding-left: 1.2rem; background: rgba(15, 23, 42, 0.2); border-radius: 8px; }
.subtit { color: #94a3b8; border-bottom: 1px dashed #334155; padding-bottom: 0.4rem; margin: 0 0 1rem 0; font-size: 0.85rem; font-weight: bold; text-transform: uppercase; letter-spacing: 0.5px; }

.lugar-card { background: #111; border: 1px solid #334155; padding: 0.8rem; border-radius: 6px; margin-bottom: 0.5rem; cursor: pointer; color: white; font-weight: 600; transition: 0.2s; }
.lugar-card:hover { border-color: #3b82f6; background: #141b2b; }
.lugar-card.activo { background: #1e3a8a; border-color: #60a5fa; box-shadow: 0 0 10px rgba(59,130,246,0.3); }

.zona-dado { background: #111; border: 1px solid #b45309; padding: 1rem; border-radius: 8px; }
.lbl-grupo { font-size: 0.8rem; color: #94a3b8; font-weight: bold; text-transform: uppercase; display: block; margin-bottom: 0.4rem; }
.dado-flex { display: flex; gap: 1rem; align-items: center; }
.input-dado { width: 75px; text-align: center; font-size: 1.4rem; font-weight: bold; background: #000; border: 2px solid #d97706; color: #facc15; border-radius: 6px; padding: 0.2rem; }
.btn-evaluar { background: #b45309; color: white; border: none; padding: 0.6rem 1.2rem; border-radius: 6px; font-weight: bold; cursor: pointer; transition: 0.2s; }
.btn-evaluar:hover { background: #d97706; }

.lista-inventario-check { display: flex; flex-direction: column; gap: 0.5rem; background: #020203; border: 1px solid #1e293b; padding: 1rem; border-radius: 8px; overflow-y: auto; flex-grow: 1; }
.item-check { display: flex; align-items: center; gap: 0.8rem; cursor: pointer; color: #cbd5e1; font-size: 0.95rem; }
.item-check input { width: 18px; height: 18px; accent-color: #facc15; }

.rareza-común { color: #cbd5e1; } .rareza-poco { color: #4ade80; font-weight: 600; } .rareza-raro { color: #3b82f6; font-weight: 600; } .rareza-épico { color: #a855f7; font-weight: 600; } .rareza-legendario { color: #facc15; font-weight: bold; text-shadow: 0 0 8px rgba(250,204,21,0.4); }

.jugadores-checks { display: flex; flex-wrap: wrap; gap: 1rem; background: #111; padding: 0.8rem; border-radius: 6px; border: 1px solid #1e293b; }
.btn-proyectar-oferta { background: #1e3a8a; border: 1px solid #3b82f6; color: white; padding: 0.8rem; border-radius: 6px; cursor: pointer; font-weight: bold; font-family: 'Cinzel', serif; }
.btn-proyectar-oferta:hover { background: #2563eb; }

/* PANEL DE CARRITOS DERECHA */
.carritos-lista { flex-grow: 1; overflow-y: auto; }
.carrito-box { background: #000; border: 1px solid #1e293b; border-radius: 8px; padding: 1rem; margin-bottom: 1rem; box-shadow: 0 4px 10px rgba(0,0,0,0.5); }
.c-head { display: flex; justify-content: space-between; border-bottom: 1px dashed #334155; padding-bottom: 0.4rem; margin-bottom: 0.6rem; color: white; }
.c-estado.pagando { color: #facc15; font-weight: bold; animation: palpitar 1.5s infinite; }
@keyframes palpitar { 50% { opacity: 0.4; } }
.c-item { display: flex; justify-content: space-between; align-items: center; font-size: 0.85rem; margin-bottom: 0.4rem; }
.c-precio-edit input { width: 75px; background: #111; border: 1px solid #475569; color: #facc15; text-align: center; border-radius: 4px; font-weight: bold; }
.c-total { text-align: right; font-weight: bold; color: #10b981; border-top: 1px solid #1e293b; padding-top: 0.4rem; margin-top: 0.6rem; }
.c-acciones { display: flex; gap: 0.5rem; margin-top: 0.8rem; }
.btn-aprobar { flex: 1; background: #15803d; color: white; border: none; padding: 0.4rem; border-radius: 4px; font-weight: bold; cursor: pointer; }
.btn-rechazar { flex: 1; background: #991b1b; color: white; border: none; padding: 0.4rem; border-radius: 4px; cursor: pointer; }

.caja-registradora-total { background: #1e1b4b; border: 2px solid #4f46e5; padding: 1rem; border-radius: 8px; text-align: center; margin-top: 1rem; display: flex; flex-direction: column; gap: 0.2rem; }
.caja-registradora-total span { font-size: 0.8rem; color: #c7d2fe; text-transform: uppercase; font-weight: bold; }
.caja-registradora-total strong { font-size: 1.3rem; color: #facc15; }
.txt-vacio { text-align: center; color: #475569; font-style: italic; margin-top: 3rem; }
</style>