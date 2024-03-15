# == Schema Information
#
# Table name: items
#
#  id                           :integer          not null, primary key
#  active                       :boolean          default(TRUE)
#  barcode_count                :integer
#  category                     :string
#  distribution_quantity        :integer
#  name                         :string
#  on_hand_minimum_quantity     :integer          default(0), not null
#  on_hand_recommended_quantity :integer
#  package_size                 :integer
#  partner_key                  :string
#  value_in_cents               :integer          default(0)
#  visible_to_partners          :boolean          default(TRUE), not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  item_category_id             :integer
#  kit_id                       :integer
#  organization_id              :integer
#

RSpec.describe Item, type: :model do
  describe 'Assocations >' do
    it { should belong_to(:item_category).optional }
  end
  context "Validations >" do
    it "must belong to an organization" do
      expect(build(:item, organization_id: nil)).not_to be_valid
    end
    it "requires a Base Item base" do
      expect(build(:item, partner_key: nil)).not_to be_valid
    end
    it "requires a unique name" do
      item = create(:item)
      expect(build(:item, name: nil)).not_to be_valid
      expect(build(:item, name: item.name)).not_to be_valid
    end
    it "requires that items quantity are not a negative number" do
      expect(build(:item, distribution_quantity: -1)).not_to be_valid
      expect(build(:item, on_hand_minimum_quantity: -1)).not_to be_valid
      expect(build(:item, on_hand_recommended_quantity: -1)).not_to be_valid
    end
  end

  context "Filtering >" do
    it "can filter" do
      expect(subject.class).to respond_to :class_filter
    end

    it "->by_size returns all items with the same size, per their BaseItem parent" do
      size4 = create(:base_item, size: "4")
      size_z = create(:base_item, size: "Z")
      create(:item, base_item: size4)
      create(:item, base_item: size4)
      create(:item, base_item: size_z)
      expect(Item.by_size("4").length).to eq(2)
    end

    it "->alphabetized retrieves items in alphabetical order" do
      Item.delete_all
      item_c = create(:item, name: "C")
      item_b = create(:item, name: "B")
      item_a = create(:item, name: "A")
      alphabetized_list = [item_a.name, item_b.name, item_c.name]
      expect(Item.alphabetized.count).to eq(3)
      expect(Item.alphabetized.map(&:name)).to eq(alphabetized_list)
    end

    it "->active shows items that are still active" do
      Item.delete_all
      inactive_item = create(:line_item, :purchase).item
      item = create(:item)
      inactive_item.destroy
      expect(Item.active.to_a).to match_array([item])
    end

    describe "->by_base_item" do
      before(:each) do
        Item.delete_all
        @c1 = create(:base_item)
        create(:item, base_item: @c1, organization: @organization)
        create(:item, base_item: create(:base_item), organization: @organization)
      end
      it "shows the items for a particular base_item" do
        expect(Item.by_base_item(@c1).size).to eq(1)
      end
      it "can be chained to organization to constrain it to just 1 org's items" do
        create(:item, base_item: @c1, organization: create(:organization))
        expect(@organization.items.by_base_item(@c1).size).to eq(1)
      end
    end

    describe "->by_partner_key" do
      it "filters by partner key" do
        Item.delete_all
        c1 = create(:base_item, partner_key: "foo")
        c2 = create(:base_item, partner_key: "bar")
        create(:item, base_item: c1, partner_key: "foo", organization: @organization)
        create(:item, base_item: c2, partner_key: "bar", organization: @organization)
        expect(Item.by_partner_key("foo").size).to eq(1)
        expect(Item.active.size).to be > 1
      end
    end

    describe "->disposable" do
      it "returns records associated with disposable diapers" do
        Item.delete_all
        base_1 = create(:base_item, category: "Diapers - Childrens")
        base_2 = create(:base_item, category: "Diapers - Adult")
        cloth_base = create(:base_item, category: "Diapers - Cloth (Adult)")

        disposable_1 = create(:item, :active, name: "Disposable Diaper 1", partner_key: base_1.partner_key)
        disposable_2 = create(:item, :active, name: "Disposable Diaper 2", partner_key: base_2.partner_key)
        cloth_1 = create(:item, :active, name: "Cloth Diaper", partner_key: cloth_base.partner_key)

        disposables = Item.disposable

        expect(disposables.count).to eq(2)
        expect(disposables).to include(disposable_1, disposable_2)
        expect(disposables).to_not include(cloth_1)
      end
    end

    describe "->cloth_diapers" do
      it "returns records associated with disposable diapers" do
        Item.delete_all
        base_1 = create(:base_item, category: "Diapers - Childrens")
        cloth_base_1 = create(:base_item, category: "Diapers - Cloth (Adult)")
        cloth_base_2 = create(:base_item, category: "Diapers - Cloth (Kids)")

        cloth_1 = create(:item, :active, name: "Cloth Diaper", partner_key: cloth_base_1.partner_key)
        cloth_2 = create(:item, :active, name: "Disposable Diaper 2", partner_key: cloth_base_2.partner_key)
        disposable_1 = create(:item, :active, name: "Disposable Diaper 1", partner_key: base_1.partner_key)

        cloth_diapers = Item.cloth_diapers

        expect(cloth_diapers.count).to eq(2)
        expect(cloth_diapers).to include(cloth_1, cloth_2)
        expect(cloth_diapers).to_not include(disposable_1)
      end
    end
  end

  context "Methods >" do
    describe "storage_locations_containing" do
      it "retrieves all storage locations that contain an item" do
        item = create(:item)
        storage_location = create(:storage_location, :with_items, item: item, item_quantity: 12)
        create(:storage_location)
        expect(Item.storage_locations_containing(item).first).to eq(storage_location)
      end
    end

    describe "barcodes_for" do
      it "retrieves all BarcodeItems associated with an item" do
        item = create(:item)
        barcode_item = create(:barcode_item, barcodeable: item)
        create(:barcode_item)
        expect(Item.barcodes_for(item).first).to eq(barcode_item)
      end
    end
    describe "barcoded_items >" do
      it "returns a collection of items that have barcodes associated with them" do
        create_list(:item, 3)
        create(:barcode_item, item: Item.first)
        create(:barcode_item, item: Item.last)
        expect(Item.barcoded_items.length).to eq(2)
      end
    end

    describe '#can_deactivate_or_delete?' do
      let(:organization) { create(:organization) }
      let(:item) { create(:item, organization: organization) }
      let(:storage_location) { create(:storage_location, organization: organization) }

      context "with no inventory" do
        it "should return true" do
          expect(item.can_deactivate_or_delete?).to eq(true)
        end
      end

      context "in a kit" do
        let(:kit) { create(:kit, organization: organization) }
        before do
          create(:line_item, itemizable: kit, item: item)
        end

        it "should return false" do
          expect(item.can_deactivate_or_delete?).to eq(false)
        end
      end

      context "with inventory" do
        before do
          TestInventory.create_inventory(organization, {
            storage_location.id => {
              item.id => 5
            }
          })
        end
        it "should return false" do
          expect(item.can_deactivate_or_delete?).to eq(false)
        end
      end
    end

    describe '#can_delete?' do
      let(:organization) { create(:organization) }
      let(:item) { create(:item, organization: organization) }
      let(:storage_location) { create(:storage_location, organization: organization) }

      context "with no inventory" do
        it "should return true" do
          expect(item.can_delete?).to eq(true)
        end
      end

      context "in a kit" do
        let(:kit) { create(:kit, organization: organization) }
        before do
          create(:line_item, itemizable: kit, item: item)
        end

        it "should return false" do
          expect(item.can_delete?).to eq(false)
        end
      end

      context "with inventory" do
        before do
          TestInventory.create_inventory(organization, {
            storage_location.id => {
              item.id => 5
            }
          })
        end
        it "should return false" do
          expect(item.can_delete?).to eq(false)
        end
      end

      context "with line items" do
        before do
          create(:donation, :with_items, item: item, storage_location: storage_location)
        end
        it "should return false" do
          expect(item.can_delete?).to eq(false)
        end
      end

      context "with barcode items" do
        before do
          item.barcode_count = 10
        end
        it "should return false" do
          expect(item.can_delete?).to eq(false)
        end
      end
    end

    describe '#deactivate!' do
      let(:item) { create(:item) }
      context "when it can deactivate" do
        it "should succeed" do
          allow(item).to receive(:can_deactivate_or_delete?).and_return(true)
          expect { item.deactivate! }.to change { item.active }.from(true).to(false)
        end
      end

      context "when it cannot deactivate" do
        it "should not succeed" do
          allow(item).to receive(:can_deactivate_or_delete?).and_return(false)
          expect { item.deactivate! }
            .to raise_error("Cannot deactivate item - it is in a storage location or kit!")
            .and not_change { item.active }
        end
      end
    end

    describe '#destroy!' do
      let(:item) { create(:item) }
      context "when it can delete" do
        it "should succeed" do
          allow(item).to receive(:can_delete?).and_return(true)
          expect { item.destroy! }.to change { Item.count }.by(-1)
        end
      end

      context "when it cannot delete" do
        it "should not succeed" do
          allow(item).to receive(:can_delete?).and_return(false)
          expect { item.destroy! }
            .to raise_error(/Failed to destroy Item/)
            .and not_change { Item.count }
          expect(item.errors.full_messages).to eq(["Cannot delete item - it has already been used!"])
        end
      end
    end

    describe "other?" do
      it "is true for items that are partner_key 'other'" do
        item = create(:item, base_item: BaseItem.first)
        other_item = create(:item, partner_key: "other")
        expect(item).not_to be_other
        expect(other_item).to be_other
      end
    end

    describe "destroy" do
      it "actually destroys an item that doesn't have history" do
        item = create(:item)
        expect { item.destroy }.to change { Item.count }.by(-1)
      end

      it "only hides an item that has history" do
        item = create(:line_item, :purchase).item
        expect { item.destroy }.to change { Item.count }.by(0).and change { Item.active.count }.by(-1)
        expect(item).not_to be_active
      end

      it 'deactivates the kit if it exists' do
        kit = create(:kit)
        item = create(:item, kit: kit)
        create(:line_item, :purchase, item: item)
        expect(kit).to be_active
        expect { item.destroy }.to change { Item.count }.by(0).and change { Item.active.count }.by(-1)
        expect(item).not_to be_active
        expect(kit).not_to be_active
      end
    end

    describe "#reactivate!" do
      context "given an array of item ids" do
        let(:item_array) { create_list(:item, 2, :inactive).collect(&:id) }
        it "sets the active trait to true for all of them" do
          expect do
            Item.reactivate(item_array)
          end.to change { Item.active.size }.by(item_array.size)
        end
      end

      context "given a single item id" do
        let(:item_id) { create(:item).id }
        it "sets the active trait to true for that item" do
          expect do
            Item.reactivate(item_id)
          end.to change { Item.active.size }.by(1)
        end
      end
    end
  end

  describe "default_quantity" do
    it "should return 50 if column is not set" do
      expect(create(:item).default_quantity).to eq(50)
    end

    it "should return the value of distribution_quantity if it is set" do
      expect(create(:item, distribution_quantity: 75).default_quantity).to eq(75)
    end

    it "should return 0 if on_hand_minimum_quantity is not set" do
      expect(create(:item).on_hand_minimum_quantity).to eq(0)
    end

    it "should return the value of on_hand_minimum_quantity if it is set" do
      expect(create(:item, on_hand_minimum_quantity: 42).on_hand_minimum_quantity).to eq(42)
    end
  end

  describe "distribution_quantity and package size" do
    it "have nil values if an empty string is passed" do
      expect(create(:item, distribution_quantity: '').distribution_quantity).to be_nil
      expect(create(:item, package_size: '').package_size).to be_nil
    end
  end

  describe "after update" do
    let(:item) { create(:item, name: "my item", kit: kit) }

    context "when item has the kit" do
      let(:kit) { create(:kit, name: "my kit") }

      it "updates kit name" do
        item.update(name: "my new name")
        expect(item.name).to eq kit.name
      end
    end

    context "when item does not have kit" do
      let(:kit) { nil }

      it "does not raise any errors" do
        allow_any_instance_of(Kit).to receive(:update).and_return(true)
        expect {
          item.update(name: "my new name")
        }.not_to raise_error
      end
    end
  end

  describe "versioning" do
    it { is_expected.to be_versioned }
  end
end
