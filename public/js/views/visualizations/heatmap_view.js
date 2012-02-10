chorus.views.visualizations.Heatmap = chorus.views.Base.extend({
    render: function() {
        var $el = $(this.el);
        $el.addClass("visualization");

        var data = new chorus.presenters.visualizations.Heatmap(this.model).present();
        var xLabels = _.uniq(_.pluck(data, 'xLabel'));
        var yLabels = _.uniq(_.pluck(data, 'yLabel'));

        var svg = d3.select(this.el).append("svg").
            attr("class", "chart heatmap").
            attr("width", 925).
            attr("height", 340);

        this.axes = new chorus.views.visualizations.Axes({
            el: svg,
            xScaleType: "numeric",
            yScaleType: "numeric",
            minXValue: _.min(xLabels[0]),
            minYValue: _.min(yLabels[0]),
            maxXValue: _.max(_.last(xLabels)),
            maxYValue: _.max(_.last(yLabels)),
            xAxisLabel: this.model.get("xAxis"),
            yAxisLabel: this.model.get("yAxis"),
            ticks: true
        });

        if (!$el.isOnDom()) return;

        this.axes.render();
        var scales = this.axes.scales();
        var fillScale = d3.scale.linear().domain([data.minValue, data.maxValue]).range(["white", "steelblue"]);

        var content = svg.append("svg:g").attr("class", "content");
        content.selectAll(".bin").data(data).enter()
            .append("svg:rect")
            .attr("class", "bin")
            .attr("x", function(row) { return scales.x(row.xLabel[0]) })
            .attr("y", function(row) { return scales.y(row.yLabel[1]) })
            .attr("height", function(row) {return Math.abs(scales.y(row.yLabel[1])-scales.y(row.yLabel[0]))-2})
            .attr("width", function(row) {return Math.abs(scales.x(row.xLabel[1])-scales.x(row.xLabel[0]))-2})
            .style("fill", function(row, i) {
                return fillScale(row.value);
            });
    }
});
