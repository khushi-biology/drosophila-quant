# Workflow

1. **Acquire.** Image stage-matched embryos of all genotypes in one session with
   identical settings, interleaving genotypes where possible. Keep a
   low-magnification DNA overview of each embryo to document its stage.
2. **Crop and segment in Fiji.** Crop fields of the blastoderm, draw one ROI per
   nucleus on the DNA channel, measure all channels (ROI Manager → *More* →
   *Multi Measure*, with *Area, Mean, Min & Max*), save the table as
   `<image>.tif_intensity.csv` ([file-naming.md](file-naming.md)).
3. **Quantify in R.** Write a configuration ([configuration.md](configuration.md))
   and run `embryoIFquant::run_experiment("config.R")`. Check `log.txt`: the
   design table, QC counts and the control-readout warnings.
4. **Check robustness (optional).** Re-segment the same crops automatically and
   re-run the pipeline on the new tables:

   ```bash
   embryo-ifquant resegment crops/ auto/ --dna-channel 2 --only-from intensity_tables/
   ```

   If a channel was not saved with the crops, locate each crop in the original
   acquisition and re-measure (`embryo_ifquant.imaging.locate_crop`,
   `measure_masks`, `embryo_ifquant.io.fiji.roi_mask`).
5. **Document the stage.** `embryo_ifquant.imaging.render_overview()` rotates
   each embryo's overview to horizontal; `locate_field()` marks where the
   high-magnification field was taken.
6. **Combine sessions.** `combine_sessions()` / `combine_experiments()` on the
   `embryo_values.csv` files of independent sessions.
7. **Figures.** Superplots and forest plots come from the pipeline
   (`superplot()`, `forest_plot()`, `save_plot(vector = TRUE)`); micrograph
   grids with `embryo_ifquant.figures.image_grid()` using one display window per
   channel from the control; multi-panel figures with `compose_panels()`;
   editable SVG with `pdf_to_svg()` and `fix_svg_for_office()`.
8. **Report.** See [documents.md](documents.md) for clickable citations,
   reference formatting, tracked changes, slide animations and PDF size.
