describe("chorus.views.DatasetListSidebar", function() {
    beforeEach(function() {
        this.view = new chorus.views.DatasetListSidebar();
    });

    describe("#render", function() {
        beforeEach(function() {
            this.view.render();
        });

        context("when no dataset is selected", function () {
            it("does not render the info section", function() {
                expect(this.view.$(".info")).not.toExist();
            });
        })

        describe("dataset:selected event handling", function() {
            context("when a dataset is selected", function() {
                beforeEach(function() {
                    this.dataset = fixtures.datasetSourceTable();
                    this.view.trigger("dataset:selected", this.dataset);
                });

                it("displays the selected dataset name", function() {
                    expect(this.view.$(".name").text().trim()).toBe(this.dataset.get("objectName"))
                });

                it("displays the selected dataset type", function() {
                    expect(this.view.$(".type").text().trim()).toBe("SOURCE_TABLE");
                });
            });
        });
    })



});
