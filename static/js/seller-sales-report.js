// Seller Sales Report - renders table and export buttons on analytics.html
(function(){
  const tableBodyId = 'salesReportTbody';
  const totalSalesId = 'salesReportTotalSales';
  const totalOrdersId = 'salesReportTotalOrders';
  const totalItemsId = 'salesReportTotalItems';

  function qs(id){ return document.getElementById(id); }
  function esc(s){ return String(s||'').replace(/[&<>"']/g, c=>({"&":"&amp;","<":"&lt;",">":"&gt;","\"":"&quot;","'":"&#39;"}[c])); }
  function formatPHP(n){ n=Number(n||0); return '₱'+n.toFixed(2); }

  async function loadSalesReport(){
    const from = (qs('dateFrom')||{}).value;
    const to = (qs('dateTo')||{}).value;
    const data = await DashboardUtils.makeApiCall(`/api/seller/sales-report?from=${from||''}&to=${to||''}`);
    if (!data || !data.success) return renderRows([],{total_sales:0,total_items:0,total_orders:0});
    renderRows(data.rows||[], data.summary||{});
  }

  function renderRows(rows, summary){
    const tbody = qs(tableBodyId);
    if (!tbody) return;

    // Totals accumulator
    const totals = { qty:0, gross:0, discount:0, refunds:0, net:0, fees:0, ship:0, profit:0 };

    if (!rows.length){
      tbody.innerHTML = `<tr><td colspan=\"16\" class=\"text-center text-muted py-3\">No sales in selected range</td></tr>`;
    } else {
      tbody.innerHTML = rows.map(r=>{
        const qty = Number(r.quantity||0);
        const unit = Number(r.price||0);
        const gross = r.subtotal != null ? Number(r.subtotal) : qty * unit;
        const discount = Number(r.discount || r.discount_amount || 0);
        const refunds = Number(r.refund || r.refund_amount || 0);
        const fees = Number(r.fees || r.platform_fees || r.commission || 0);
        const ship = Number(r.seller_shipping_cost || r.shipping_cost_seller || 0);
        const net = gross - discount - refunds;
        const profit = net - fees - ship;

        // accumulate
        totals.qty += qty;
        totals.gross += gross;
        totals.discount += discount;
        totals.refunds += refunds;
        totals.net += net;
        totals.fees += fees;
        totals.ship += ship;
        totals.profit += profit;

        return `
        <tr>
          <td>${esc(r.date ? new Date(r.date).toLocaleString() : '')}</td>
          <td>${esc(r.order_number)}</td>
          <td>${esc(r.product)}</td>
          <td>${esc([r.size||'', r.color||''].filter(Boolean).join(' / '))}</td>
          <td class=\"text-end\">${qty}</td>
          <td class=\"text-end\">${formatPHP(unit)}</td>
          <td class=\"text-end\">${formatPHP(gross)}</td>
          <td class=\"text-end\">${formatPHP(discount)}</td>
          <td class=\"text-end\">${formatPHP(refunds)}</td>
          <td class=\"text-end\">${formatPHP(net)}</td>
          <td class=\"text-end\">${formatPHP(fees)}</td>
          <td class=\"text-end\">${formatPHP(ship)}</td>
          <td class=\"text-end\">${formatPHP(profit)}</td>
          <td>${esc(r.status||'')}</td>
          <td>${esc(r.payment_status||'')}</td>
          <td>${esc(r.buyer||'')}</td>
        </tr>`;
      }).join('');
    }

    // Update top summary cards (keep backend summary when available)
    if (qs(totalSalesId)) qs(totalSalesId).textContent = formatPHP((summary||{}).total_sales != null ? summary.total_sales : totals.net);
    if (qs(totalOrdersId)) qs(totalOrdersId).textContent = String((summary||{}).total_orders || 0);
    if (qs(totalItemsId)) qs(totalItemsId).textContent = String((summary||{}).total_items != null ? summary.total_items : totals.qty);

    // Update footer totals
    const setText = (id, val) => { const el = qs(id); if (el) el.textContent = val; };
    setText('sfTotalQty', String(totals.qty));
    setText('sfTotalGross', formatPHP(totals.gross));
    setText('sfTotalDiscounts', formatPHP(totals.discount));
    setText('sfTotalRefunds', formatPHP(totals.refunds));
    setText('sfTotalNet', formatPHP(totals.net));
    setText('sfTotalFees', formatPHP(totals.fees));
    setText('sfTotalShip', formatPHP(totals.ship));
    setText('sfTotalProfit', formatPHP(totals.profit));
  }

  function exportCSV(){
    const table = qs('salesReportTable');
    if (!table) return;
    const rows = Array.from(table.querySelectorAll('tr'));
    const csv = rows.map(tr => Array.from(tr.querySelectorAll('th,td')).map(td => {
      const txt = td.innerText.replace(/\s+/g,' ').trim();
      const safe = '"'+txt.replace(/"/g,'""')+'"';
      return safe;
    }).join(',')).join('\r\n');
    const blob = new Blob([csv], {type:'text/csv;charset=utf-8;'});
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url; a.download = `sales-report-${new Date().toISOString().slice(0,10)}.csv`;
    document.body.appendChild(a); a.click(); document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }

  function exportPDF(){
    // Print-friendly approach
    const printWin = window.open('', '_blank');
    if (!printWin) return;
    const tableHtml = (qs('salesReportContainer')||{innerHTML:''}).innerHTML;
    printWin.document.write(`<!DOCTYPE html><html><head><title>Sales Report</title>
      <style>table{width:100%;border-collapse:collapse} th,td{border:1px solid #999;padding:6px;font-size:12px} th{text-align:left;background:#eee}</style>
    </head><body>
      <h3>Sales Report</h3>
      ${tableHtml}
    </body></html>`);
    printWin.document.close();
    printWin.focus();
    printWin.print();
  }

  document.addEventListener('DOMContentLoaded', function(){
    const applyBtn = document.getElementById('applyFilters');
    if (applyBtn) applyBtn.addEventListener('click', loadSalesReport);
    const resetBtn = document.getElementById('resetFilters');
    if (resetBtn) resetBtn.addEventListener('click', () => setTimeout(loadSalesReport, 50));
    const csvBtn = qs('btnExportCSV'); if (csvBtn) csvBtn.addEventListener('click', exportCSV);
    const pdfBtn = qs('btnExportPDF'); if (pdfBtn) pdfBtn.addEventListener('click', exportPDF);
    // initial
    setTimeout(loadSalesReport, 100);
  });
})();