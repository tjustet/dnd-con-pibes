<script setup>
import { ref, onMounted, computed, watch } from 'vue'

const props = defineProps({
  campaignId: { type: [String, Number], required: true },
  jugadores: { type: Array, default: () => [] },
  carritosMesa: { type: Object, default: () => ({}) } // Recibimos los carritos en tiempo real
})

const supabase = useSupabaseClient()
const emit = defineEmits(['cerrar', 'proyectarVision', 'proyectarTienda', 'actualizarCarritos', 'aprobarCompra', 'rechazarCompra'])

const lugares = ref([])
const catalogoObjetos = ref([])
const lugarSeleccionado = ref(null)
const cargando = ref(true)

// Control de revelación
const tiradaInvestigacion = ref(10)
const objetosRevelados = ref([]) 
const jugadoresDestino = ref([]) 

const cargarTiendas = async () => {
  const { data: objData } = await supabase.from('objetos').select('*')
  if (objData) catalogoObjetos.value = objData
  const { data: lugData } = await supabase.from('lugares').select('*').eq('campaign_id', props.campaignId)
  if (lugData) lugares.value = lugData
  cargando.value = false
}

const objetosDelLugar = computed(() => {
  if (!lugarSeleccionado.value || !lugarSeleccionado.value.objetos) return []
  return catalogoObjetos.value.filter(obj => lugarSeleccionado.value.objetos.includes(obj.id))
})

// CORRECCIÓN TIRADA D20 (Búsqueda exacta)
const aplicarTiradaD20 = () => {
  const tirada = tiradaInvestigacion.value
  objetosRevelados.value = [] 
  
  objetosDelLugar.value.forEach(obj => {
    let revela = false
    const rareza = (obj.rareza || 'común').toLowerCase().trim()
    
    if (rareza === 'común' && tirada >= 5) revela = true
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
  // Ya no cerramos el modal acá
}

// Convertidor para leer fácil
const desglosar = (total) => {
  let r = total; const po = Math.floor(r/1000); r%=1000; const pp = Math.floor(r/100); r%=100; return `${po}po ${pp}pp ${r}pc`
}

// Modificar precio en el carrito del jugador
const cambiarPrecioDM = (pjId, itemIdx, nuevoPrecioStr) => {
  const nuevosCarritos = JSON.parse(JSON.stringify(props.carritosMesa))
  nuevosCarritos[pjId].items[itemIdx].precio_dm = parseInt(nuevoPrecioStr) || 0
  
  // Recalcular total
  nuevosCarritos[pjId].total = nuevosCarritos[pjId].items.reduce((acc, it) => acc + (it.precio_dm ?? it.precio_original), 0)
  emit('actualizarCarritos', nuevosCarritos)
}

onMounted(() => { cargarTiendas() })
</script>

<template>
  <div class="modal-dm-overlay" @click.self="$emit('cerrar')">
    <div class="modal-dm-sheet tienda-sheet">
      
      <div class="header-tienda-dm">
        <h3>🏪 Mostrador del DM</h3>
        <button class="btn-cerrar" @click="$emit('cerrar')">✖</button>
      </div>

      <div v-if="cargando" class="cargando-txt">Armando la tienda...</div>

      <div v-else class="layout-tienda-dm">
        
        <div class="col-panel col-lugares">
          <h4 class="subtit">Locales</h4>
          <div class="lista-items">
            <div v-for="lugar in lugares" :key="lugar.id" class="lugar-card" :class="{'activo': lugarSeleccionado?.id === lugar.id}" @click="lugarSeleccionado = lugar; objetosRevelados = []">
              {{ lugar.nombre }}
            </div>
          </div>
        </div>

        <div class="col-panel col-detalles" v-if="lugarSeleccionado">
          <h4 class="subtit">Mostrando: {{ lugarSeleccionado.nombre }}</h4>
          
          <div class="zona-dado">
            <label>Investigación del PJ (D20):</label>
            <div class="dado-flex">
              <input type="number" v-model="tiradaInvestigacion" class="input-dado" min="1" max="40" />
              <button @click="aplicarTiradaD20" class="btn-accion-dm">Buscar Items</button>
            </div>
          </div>

          <div class="lista-inventario-check mt-1">
            <label v-for="obj in objetosDelLugar" :key="obj.id" class="item-check">
              <input type="checkbox" :value="obj.id" v-model="objetosRevelados">
              <span :class="'rareza-' + (obj.rareza || '').split(' ')[0].toLowerCase().replace(' ','')">
                {{ obj.nombre }} ({{ obj.rareza }}) - {{ desglosar(obj.valor_cobre) }}
              </span>
            </label>
          </div>

          <button @click="mostrarInventarioLugar" class="btn-guardar-creacion dorado mt-1">
            📢 Proyectar Oferta a Jugadores
          </button>
        </div>
        <div v-else class="col-panel col-detalles vacio">Selecciona un local.</div>

        <div class="col-panel col-carritos">
          <h4 class="subtit">Caja Registradora (En vivo)</h4>
          <div class="carritos-lista">
            
            <div v-for="(cart, pjId) in carritosMesa" :key="pjId" class="carrito-box" v-show="cart.items.length > 0">
              <div class="c-head">
                <strong>{{ jugadores.find(j => j.id === pjId)?.nombre_pj || 'PJ' }}</strong>
                <span class="c-estado" :class="cart.estado">{{ cart.estado === 'pagando' ? '💰 Esperando Pago' : '🛒 Mirando' }}</span>
              </div>
              
              <div v-for="(it, idx) in cart.items" :key="idx" class="c-item">
                <span class="c-nom">{{ it.nombre }}</span>
                <div class="c-precio-edit">
                  <input type="number" :value="it.precio_dm ?? it.precio_original" @change="e => cambiarPrecioDM(pjId, idx, e.target.value)" title="Modificar precio (en Cobre)" />
                  <span>pc</span>
                </div>
              </div>

              <div class="c-total">Total DM: {{ desglosar(cart.total) }}</div>

              <div class="c-acciones" v-if="cart.estado === 'pagando'">
                <button class="btn-rechazar" @click="$emit('rechazarCompra', pjId)">Rechazar</button>
                <button class="btn-aprobar" @click="$emit('aprobarCompra', pjId)">Aceptar Pago</button>
              </div>
            </div>

            <div v-if="Object.keys(carritosMesa).length === 0" class="txt-vacio">Nadie está comprando nada.</div>
          </div>
        </div>

      </div>
    </div>
  </div>
</template>

<style scoped>
@import url('https://fonts.googleapis.com/css2?family=Cinzel:wght@700&display=swap');
.modal-dm-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.85); display: flex; align-items: center; justify-content: center; z-index: 99999; padding: 1rem; }
.tienda-sheet { width: 100%; max-width: 1200px; height: 85vh; display: flex; flex-direction: column; background: #0a0a0c; border: 2px solid #3b82f6; border-radius: 12px; }
.header-tienda-dm { display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #1e293b; padding: 1rem; margin-bottom: 1rem; }
.header-tienda-dm h3 { font-family: 'Cinzel', serif; color: #facc15; margin: 0; }
.btn-cerrar { background: transparent; border: none; color: #94a3b8; font-size: 1.5rem; cursor: pointer; }

/* 3 COLUMNAS AHORA */
.layout-tienda-dm { display: grid; grid-template-columns: 220px 1fr 350px; gap: 1.5rem; flex-grow: 1; overflow: hidden; padding: 0 1rem 1rem 1rem; }
.col-panel { display: flex; flex-direction: column; overflow-y: auto; padding-right: 0.5rem; }
.col-lugares { border-right: 1px solid #1e293b; }
.col-carritos { border-left: 1px solid #1e293b; padding-left: 1rem; background: rgba(15, 23, 42, 0.3); border-radius: 8px; }
.subtit { color: #94a3b8; border-bottom: 1px dashed #334155; padding-bottom: 0.3rem; margin: 0 0 1rem 0; font-size: 0.9rem; text-transform: uppercase; }

/* Lógica interna igual que antes pero ajustada */
.lugar-card { background: #111; border: 1px solid #334155; padding: 0.8rem; border-radius: 6px; margin-bottom: 0.5rem; cursor: pointer; color: white; }
.lugar-card.activo { background: #1e3a8a; border-color: #60a5fa; font-weight: bold; }
.zona-dado { background: #111; border: 1px solid #b45309; padding: 1rem; border-radius: 8px; }
.dado-flex { display: flex; gap: 1rem; align-items: center; margin-top: 0.5rem; }
.input-dado { width: 70px; text-align: center; font-size: 1.5rem; font-weight: bold; background: #000; border: 2px solid #d97706; color: #facc15; border-radius: 6px; }
.btn-accion-dm { background: #1e293b; border: 1px solid #3b82f6; color: white; padding: 0.6rem 1rem; border-radius: 6px; cursor: pointer; }
.lista-inventario-check { display: flex; flex-direction: column; gap: 0.4rem; background: #000; border: 1px solid #1e293b; padding: 1rem; border-radius: 8px; overflow-y: auto; }
.item-check { display: flex; align-items: center; gap: 0.8rem; cursor: pointer; color: #cbd5e1; }
.item-check input { width: 18px; height: 18px; accent-color: #facc15; }
.rareza-común { color: #cbd5e1; } .rareza-poco { color: #4ade80; } .rareza-raro { color: #60a5fa; } .rareza-épico { color: #a855f7; } .rareza-legendario { color: #facc15; }
.btn-guardar-creacion.dorado { background: #b45309; color: white; border: none; padding: 1rem; border-radius: 6px; cursor: pointer; font-weight: bold; }

/* CARRITOS */
.carrito-box { background: #000; border: 1px solid #3b82f6; border-radius: 8px; padding: 1rem; margin-bottom: 1rem; }
.c-head { display: flex; justify-content: space-between; border-bottom: 1px dashed #334155; padding-bottom: 0.5rem; margin-bottom: 0.8rem; color: white; }
.c-estado.comprando { color: #94a3b8; } .c-estado.pagando { color: #facc15; font-weight: bold; animation: titilar 1s infinite; }
@keyframes titilar { 50% { opacity: 0.5; } }
.c-item { display: flex; justify-content: space-between; align-items: center; font-size: 0.85rem; color: #cbd5e1; margin-bottom: 0.4rem; }
.c-precio-edit { display: flex; align-items: center; gap: 0.3rem; }
.c-precio-edit input { width: 60px; background: #111; border: 1px solid #475569; color: #facc15; text-align: right; border-radius: 4px; padding: 0.2rem; }
.c-total { text-align: right; margin-top: 1rem; color: #4ade80; font-weight: bold; border-top: 1px solid #1e293b; padding-top: 0.5rem; }
.c-acciones { display: flex; gap: 0.5rem; margin-top: 1rem; }
.btn-aprobar { flex: 1; background: #166534; border: 1px solid #22c55e; color: white; padding: 0.5rem; border-radius: 4px; cursor: pointer; font-weight: bold; }
.btn-rechazar { flex: 1; background: #7f1d1d; border: 1px solid #ef4444; color: white; padding: 0.5rem; border-radius: 4px; cursor: pointer; }
.txt-vacio { text-align: center; color: #64748b; font-style: italic; margin-top: 2rem; }
</style>