# Example on synthetic data

No real data are included in this repository. These two files create a small
synthetic experiment and analyse it end to end.

```bash
pip install -e "python[all]"                 # from the repository root
python examples/make_synthetic_data.py       # writes examples/data/ (not tracked by git)
Rscript -e 'embryoIFquant::run_experiment("examples/config_example.R")'
```

Expected result in `examples/out/tables/effects_vs_control.csv`: MutA shows about
1.5-fold more MARK / H3 than WT; MutB does not differ. The superplots are in
`examples/out/figures/`.

Re-segmenting the crops gives the same tables:

```bash
embryo-ifquant resegment examples/data/crops examples/data/auto_tables --dna-channel 2
```
