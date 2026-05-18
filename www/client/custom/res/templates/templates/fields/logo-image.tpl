<style>
.cell[data-name="logoUrl"] .control-label { display: none !important; }
</style>
{{#if logoUrl}}
<img src="{{logoUrl}}" alt="Logo" style="width:80px;height:80px;object-fit:contain;border-radius:8px;border:1px solid #e0e4ea;background:#f4f6f8;">
{{else}}
<div style="width:80px;height:80px;border-radius:8px;background:#1a73e8;display:flex;align-items:center;justify-content:center;font-size:26px;font-weight:700;color:#fff;letter-spacing:2px;">{{initials}}</div>
{{/if}}
